//
//  ChallengesService.swift
//  Challengr
//
//  Created by Julian Richter on 26.11.25.
//

import Foundation
import CoreLocation

typealias PlayerData = [String: Player]


let urlPlayersNearby = URL(string: "http://localhost:8080/players/nearby")!

struct NearbyRequest: Codable {
    let latitude: Double
    let longitude: Double
    let radius: Double
    let playerId: Int64
}

func loadPlayersNearby(currentLocation: CLLocationCoordinate2D, ownPlayerId: Int64) async throws -> PlayerData {

    var request = URLRequest(url: urlPlayersNearby)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = NearbyRequest(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        radius: 50,           // 50m Radius
        playerId: ownPlayerId // eigener Spieler bleibt immer sichtbar
    )

    request.httpBody = try JSONEncoder().encode(body)

    let (data, _) = try await URLSession.shared.data(for: request)

    print("Nearby players loaded:", String(decoding: data, as: UTF8.self))

    // Zurzeit PlayerData = [String: [String]] - deswegen decodieren
    return try JSONDecoder().decode(PlayerData.self, from: data)
}
