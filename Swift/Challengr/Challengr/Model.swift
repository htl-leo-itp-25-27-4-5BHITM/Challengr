//
//  ModelService.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import Foundation
import CoreLocation

// Spieler, so wie er vom Backend kommt
struct PlayerDTO: Codable, Identifiable {
    let id: Int64
    let name: String
    let latitude: Double
    let longitude: Double
}

// Request für /players/nearby
struct NearbyRequest: Codable {
    let playerId: Int64
    let latitude: Double
    let longitude: Double
    let radius: Double
}

// Optional: Wrapper für Marker auf der Map
struct PlayerMarker: Identifiable {
    let id: Int64
    let name: String
    let coordinate: CLLocationCoordinate2D
}



