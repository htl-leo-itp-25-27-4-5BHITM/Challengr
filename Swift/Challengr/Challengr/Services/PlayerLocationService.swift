import Foundation
import CoreLocation

final class PlayerLocationService {

    // MARK: - Configuration (Konfiguration)

    private let baseURL = BackendConfig.apiURL("api/players")

    // MARK: - Player updates (Spieler-Updates)

    /// Updates an existing player (Aktualisiert einen existierenden Spieler)
    /// PUT: send position/name only, no points (PUT: nur Position/Name schicken, keine Punkte)
    func updatePlayer(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        let url = baseURL.appendingPathComponent("\(id)")

    let dto = PlayerRequestDTO(id: id, name: name, keycloakId: nil, latitude: latitude, longitude: longitude)

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(dto)

        _ = try await API.data(for: request)
    }

    /// Creates a new player (Erstellt neuen Spieler)
    func createPlayer(
        name: String,
        keycloakId: String? = nil,
        latitude: Double = 0,
        longitude: Double = 0
    ) async throws -> PlayerDTO {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            PlayerRequestDTO(id: nil, name: name, keycloakId: keycloakId, latitude: latitude, longitude: longitude)
        )

        let (data, _) = try await API.data(for: request)
        return try JSONDecoder().decode(PlayerDTO.self, from: data)
    }


    // MARK: - Player fetch (Spieler laden)

    /// Loads nearby players (inkl. ggf. eigenem Spieler)
    /// (Holt Spieler in der Nähe, falls Backend ihn zurückgibt)
    func loadNearbyPlayers(
        currentPlayerId: String,
        latitude: Double,
        longitude: Double,
        radius: Double
    ) async throws -> [PlayerDTO] {

        var components = URLComponents(url: baseURL.appendingPathComponent("nearby"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "playerId", value: String(currentPlayerId)),
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radius))
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await loadNearby(request: request).players
    }

    /// Spieler in der Nähe plus Gesamtzahl: der Server schickt höchstens die 30 nächsten,
    /// die echte Anzahl steht im Header X-Nearby-Total (z. B. 187 auf dem Schulhof).
    func loadNearbyWithTotal(latitude: Double, longitude: Double, radius: Double) async throws -> (players: [PlayerDTO], total: Int) {
        var components = URLComponents(url: baseURL.appendingPathComponent("nearby"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radius))
        ]
        return try await loadNearby(request: URLRequest(url: components.url!))
    }

    private func loadNearby(request: URLRequest) async throws -> (players: [PlayerDTO], total: Int) {
        let (data, response) = try await API.data(for: request)
        let players = try JSONDecoder().decode([PlayerDTO].self, from: data)
        let header = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Nearby-Total")
        return (players, header.flatMap(Int.init) ?? players.count)
    }


    /// Loads a player by id (Spieler per ID laden)
    func loadPlayerById(id: String) async throws -> PlayerDTO {
        let url = baseURL.appendingPathComponent(id)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, _) = try await API.data(for: request)
        return try JSONDecoder().decode(PlayerDTO.self, from: data)
    }

    /// Eigenes Konto endgültig löschen (Keycloak-Konto + Spieldaten)
    func deleteOwnAccount() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("me"))
        request.httpMethod = "DELETE"
        let (_, response) = try await API.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, (200...299).contains(status) else {
            throw URLError(.badServerResponse)
        }
    }

    /// "Unsichtbar": nicht mehr bei anderen auf der Karte (Standortschutz)
    func setInvisible(id: String, invisible: Bool) async throws -> PlayerDTO {
        var request = URLRequest(url: baseURL.appendingPathComponent(id).appendingPathComponent("visibility"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["invisible": invisible])
        let (data, response) = try await API.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(PlayerDTO.self, from: data)
    }

    /// Loads daily streak (Tagesstreak laden)
    func loadPlayerStreak(id: String) async throws -> Int {
        let url = baseURL
            .appendingPathComponent(id)
            .appendingPathComponent("streak")

        let (data, _) = try await API.data(from: url)
        return try JSONDecoder().decode(Int.self, from: data)
    }



}

// MARK: - Points & stats (Punkte & Statistiken)

struct PlayerPointsDTO: Codable {
    let playerId: String
    let points: Int
}

extension PlayerLocationService {
    /// Loads total points (Gesamtpunkte laden)
    func loadPlayerPoints(id: String) async throws -> Int {
        let url = baseURL
            .appendingPathComponent(id)
            .appendingPathComponent("points")

        let (data, _) = try await API.data(from: url)
        let dto = try JSONDecoder().decode(PlayerPointsDTO.self, from: data)
        return dto.points
    }
    
    /// Loads total/won challenges (Gesamt/Gewonnen laden)
    func loadPlayerStats(id: String) async throws -> PlayerStatsDTO {
        let url = baseURL
            .appendingPathComponent(id)
            .appendingPathComponent("stats")
        let (data, _) = try await API.data(from: url)
        return try JSONDecoder().decode(PlayerStatsDTO.self, from: data)
    }

    // MARK: - Battles & profile (Battles & Profil)

    /// Loads battle history (Battle-Verlauf laden)
    func loadPlayerBattles(id: String) async throws -> [BattleHistoryDTO] {
        let url = baseURL
            .appendingPathComponent(id)
            .appendingPathComponent("battles")
        let (data, response) = try await API.data(from: url)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 404 {
                print("Battle history not available (404):", url.absoluteString)
                return []
            }

            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                let snippet = String(data: data, encoding: .utf8) ?? "<no body>"
                print("Battle history failed (\(httpResponse.statusCode)):", url.absoluteString)
                print("Response snippet:", snippet.prefix(200))
                return []
            }
        }

        do {
            return try JSONDecoder().decode([BattleHistoryDTO].self, from: data)
        } catch {
            let snippet = String(data: data, encoding: .utf8) ?? "<no body>"
            print("Battle history decode failed:", url.absoluteString)
            print("Response snippet:", snippet.prefix(200))
            return []
        }
    }

    /// Loads profile status/badges (Profil-Status/Badges laden)
    func loadPlayerProfile(id: String) async throws -> PlayerProfileDTO {
        let url = baseURL
            .appendingPathComponent(id)
            .appendingPathComponent("profile")
        let (data, _) = try await API.data(from: url)
        return try JSONDecoder().decode(PlayerProfileDTO.self, from: data)
    }

    // MARK: - Loudness best (Loudness-Bestwert)

    func loadPlayerBestLoudness(id: String) async throws -> Double? {
        let url = baseURL
            .appendingPathComponent(id)
            .appendingPathComponent("loudness-best")
        let (data, _) = try await API.data(from: url)
        let dto = try JSONDecoder().decode(PlayerLoudnessBestDTO.self, from: data)
        return dto.bestLoudness
    }

    func updatePlayerBestLoudness(id: String, best: Double) async throws -> Double? {
        let url = baseURL
            .appendingPathComponent(id)
            .appendingPathComponent("loudness-best")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(PlayerLoudnessBestDTO(bestLoudness: best))

        let (data, _) = try await API.data(for: request)
        let dto = try JSONDecoder().decode(PlayerLoudnessBestDTO.self, from: data)
        return dto.bestLoudness
    }
}

struct PlayerStatsDTO: Decodable {
    let totalChallenges: Int
    let wonChallenges: Int
}




