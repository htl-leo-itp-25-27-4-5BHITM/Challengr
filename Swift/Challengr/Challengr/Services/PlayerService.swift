//
//  PlayerService.swift
//  Challengr
//
//  Created by Julian Richter on 26.11.25.
//

import Foundation
import CoreLocation

class PlayerService {
    static let shared = PlayerService()
    private init() {}

    private let baseURL = "http://localhost:8080/api/players"
    private let defaultsKey = "playerId"

    var playerId: Int64? {
        get { UserDefaults.standard.object(forKey: defaultsKey) as? Int64 }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    // MARK: Neuer Spieler erstellen
    func createPlayer(name: String, location: CLLocationCoordinate2D) async throws -> Player {
        struct CreatePlayerRequest: Codable {
            let name: String
            let latitude: Double
            let longitude: Double
        }

        let body = CreatePlayerRequest(name: name, latitude: location.latitude, longitude: location.longitude)

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let player = try JSONDecoder().decode(Player.self, from: data)
        self.playerId = Int64(player.id)
        return player
    }

    


    // MARK: Spieler erstellen oder Position aktualisieren
    func updateOrCreatePlayer(name: String, location: CLLocationCoordinate2D) async throws {
        if let id = playerId {
            do {
                try await updatePlayerPosition(location: location)
                print("Updated position")
            } catch {
                print("Update failed, creating new player: \(error)")
                playerId = nil
                let newPlayer = try await createPlayer(name: name, location: location)
                print("Created new player with id \(newPlayer.id)")
            }
        } else {
            let newPlayer = try await createPlayer(name: name, location: location)
            print("Created new player with id \(newPlayer.id)")
        }
    }


    // MARK: Spielerposition updaten
    func updatePlayerPosition(location: CLLocationCoordinate2D) async throws {
        guard let playerId = playerId else { return }

        struct UpdatePlayerRequest: Codable {
            let latitude: Double
            let longitude: Double
        }

        let body = UpdatePlayerRequest(latitude: location.latitude, longitude: location.longitude)

        var request = URLRequest(url: URL(string: "\(baseURL)/\(playerId)")!) // ID in URL
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        _ = try await URLSession.shared.data(for: request)
    }

}
