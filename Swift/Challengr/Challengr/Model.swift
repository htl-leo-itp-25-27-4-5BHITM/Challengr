//
//  ModelService.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import Foundation
import CoreLocation

// MARK: - Player DTOs (Spieler-DTOs)

// Player payload for write operations (Spieler-Request ohne Punkte)
struct PlayerRequestDTO: Codable {
    let id: Int64?
    let name: String
    let keycloakId: String?
    let latitude: Double
    let longitude: Double
}

// Player payload for read operations (Spieler-Response mit Punkten)
struct PlayerDTO: Codable, Identifiable {
    let id: Int64
    let name: String
    let latitude: Double
    let longitude: Double
    let points: Int
    let rankName: String
}

// MARK: - Challenge DTOs (Challenge-DTOs)

struct ChallengeDTO: Codable, Identifiable {
    let id: Int64
    let text: String
    let category: String
    let choices: [String]?    // bei Wissen gefüllt
    let correctIndex: Int?    // bei Wissen (0–3)
}

// MARK: - Profile & History DTOs (Profil & Verlauf DTOs)

struct PlayerPointsHistoryDTO: Codable, Identifiable {
    let id = UUID()
    let date: String
    let points: Int
}

struct BattleHistoryDTO: Codable, Identifiable {
    let id: Int64
    let createdAt: String
    let challengeText: String
    let category: String
    let opponentName: String
    let winnerName: String?
    let status: String
    let pointsDelta: Int
    let won: Bool
}

struct PlayerProfileDTO: Codable {
    let status: String?
    let badges: [String]
}

struct PlayerLoudnessBestDTO: Codable {
    let bestLoudness: Double?
}

// MARK: - Backend config (Backend-Konfiguration)

enum BackendEnvironment: String {
    case cloud
}

struct BackendConfig {
    private static let cloudBaseURL = URL(string: "https://it220257.cloud.htl-leonding.ac.at")!

    static var baseURL: URL {
        cloudBaseURL
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




