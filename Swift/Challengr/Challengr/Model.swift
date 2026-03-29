//
//  ModelService.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import Foundation
import CoreLocation

// Spieler, so wie er vom Backend kommt
// Nur für Requests (Client → Backend), ohne Punkte
struct PlayerRequestDTO: Codable {
    let id: Int64?
    let name: String
    let latitude: Double
    let longitude: Double
}

// Für Responses (Backend → Client), inkl. Punkte
struct PlayerDTO: Codable, Identifiable {
    let id: Int64
    let name: String
    let latitude: Double
    let longitude: Double
    let points: Int
    let rankName: String
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

struct ChallengeDTO: Codable, Identifiable {
    let id: Int64
    let text: String
    let category: String
    let choices: [String]?    // bei Wissen gefüllt
    let correctIndex: Int?    // bei Wissen (0–3)
}

struct KnowledgeQuestionDTO: Codable {
    let text: String
    let choices: [String]
}

enum BackendEnvironment: String {
    case cloud
    case local
}

struct BackendConfig {
    private static let cloudBaseURL = URL(string: "https://it220257.cloud.htl-leonding.ac.at")!
    private static let localBaseURL = URL(string: "http://localhost:8080")!
    static let useLocalBackendKey = "useLocalBackend"

    static var environment: BackendEnvironment {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: useLocalBackendKey) ? .local : .cloud
        #else
        return .cloud
        #endif
    }

    static var baseURL: URL {
        environment == .local ? localBaseURL : cloudBaseURL
    }

    static func apiURL(_ path: String) -> URL {
        let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return baseURL.appendingPathComponent(normalized)
    }

    static func gameWebSocketURL(playerId: Int64) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components.path = "/ws/game"
        components.queryItems = [
            URLQueryItem(name: "playerId", value: String(playerId))
        ]
        return components.url!
    }
}




