import Foundation
import CoreLocation

final class PlayerLocationService {

    private let baseURL = BackendConfig.apiURL("api/players")


    /// Aktualisiert einen existierenden Spieler in der DB
    // PUT: nur Position/Name schicken, keine Punkte
    func updatePlayer(
        id: Int64,
        name: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        let url = baseURL.appendingPathComponent("\(id)")

        let dto = PlayerRequestDTO(id: id, name: name, latitude: latitude, longitude: longitude)

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(dto)

        _ = try await URLSession.shared.data(for: request)
    }


    /// Holt Spieler in der Nähe (inkl. eigenem Spieler)
    /// Holt Spieler in der Nähe (inkl. eigenem Spieler, falls Backend ihn zurückgibt)
    func loadNearbyPlayers(
        currentPlayerId: Int64,
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

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([PlayerDTO].self, from: data)
    }
    

    func loadPlayerById(id: Int64) async throws -> PlayerDTO {
        let url = baseURL.appendingPathComponent("\(id)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(PlayerDTO.self, from: data)
    }

    func loadPlayerStreak(id: Int64) async throws -> Int {
        let url = baseURL
            .appendingPathComponent("\(id)")
            .appendingPathComponent("streak")

        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Int.self, from: data)
    }



}

struct PlayerPointsDTO: Codable {
    let playerId: Int64
    let points: Int
}

extension PlayerLocationService {
    func loadPlayerPoints(id: Int64) async throws -> Int {
        let url = baseURL
            .appendingPathComponent("\(id)")
            .appendingPathComponent("points")

        let (data, _) = try await URLSession.shared.data(from: url)
        let dto = try JSONDecoder().decode(PlayerPointsDTO.self, from: data)
        return dto.points
    }
    
    func loadPlayerStats(id: Int64) async throws -> PlayerStatsDTO {
        let url = baseURL
            .appendingPathComponent("\(id)")
            .appendingPathComponent("stats")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(PlayerStatsDTO.self, from: data)
    }

    func loadPlayerPointsHistory(id: Int64) async throws -> [PlayerPointsHistoryDTO] {
        let url = baseURL
            .appendingPathComponent("\(id)")
            .appendingPathComponent("points-history")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([PlayerPointsHistoryDTO].self, from: data)
    }

    func loadPlayerBattles(id: Int64) async throws -> [BattleHistoryDTO] {
        let url = baseURL
            .appendingPathComponent("\(id)")
            .appendingPathComponent("battles")
        let (data, response) = try await URLSession.shared.data(from: url)

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
}

struct PlayerStatsDTO: Decodable {
    let totalChallenges: Int
    let wonChallenges: Int
}




