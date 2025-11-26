//
//  ChallengesService.swift
//  Challengr
//
//  Created by Julian Richter on 26.11.25.
//

import Foundation
import CoreLocation

typealias PlayerData = [Player]



let urlPlayersNearby = URL(string: "http://localhost:8080/api/players/nearby")!

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
        radius: 200,
        playerId: ownPlayerId
    )

    request.httpBody = try JSONEncoder().encode(body)

    // Daten vom Server abrufen
    let (data, _) = try await URLSession.shared.data(for: request)

    // Raw Response loggen
    print("Nearby players raw response:")
    print(String(decoding: data, as: UTF8.self))

    // Decoding in PlayerData (Array)
    let players = try JSONDecoder().decode(PlayerData.self, from: data)

    // Optional: schön formatiert loggen
    let pretty = try JSONEncoder().encode(players)
    print("Decoded players JSON:")
    print(String(data: pretty, encoding: .utf8)!)

    // Rückgabe an den Aufrufer
    return players
}


