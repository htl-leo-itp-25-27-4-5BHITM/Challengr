import Foundation
import CoreLocation

final class PlayerLocationService {

    // Im Simulator: Backend läuft auf dem Mac
    private let baseURL = "http://localhost:8080/api/players"


    /// Aktualisiert einen existierenden Spieler in der DB
    func updatePlayer(
        id: Int64,
        name: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        guard let url = URL(string: "\(baseURL)/\(id)") else { return }

        let dto = PlayerDTO(id: id, name: name, latitude: latitude, longitude: longitude)

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

        var components = URLComponents(string: "\(baseURL)/nearby")!
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
        guard let url = URL(string: "\(baseURL)/\(id)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(PlayerDTO.self, from: data)
    }


}
