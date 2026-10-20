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
    let id: String?
    let name: String
    let keycloakId: String?
    let latitude: Double
    let longitude: Double
}

// Player payload for read operations (Spieler-Response mit Punkten)
struct PlayerDTO: Codable, Identifiable {
    let id: String
    let name: String
    /// Eigenes Konto: genau; "nearby": gerundet (~50 m); fremdes Profil: nil (Standortschutz)
    let latitude: Double?
    let longitude: Double?
    let points: Int
    let rankName: String
    /// Gewählte Spielfigur (z.B. "sir-brecht"); nil bei Spielern ohne Wahl oder alten Backends.
    var character: String? = nil
    /// Liga-Trophäen (Quiz-Show und Real-Life gemeinsam; nil bei alten Backends)
    var trophies: Int? = nil
    /// "Unsichtbar" (nur beim eigenen Konto gesetzt)
    var invisible: Bool? = nil
    /// Persönlicher Rekord: höchster je erreichter Trophäen-Stand (nil bei alten Backends)
    var highestTrophies: Int? = nil
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
    /// FRIENDLY, RANKED_KNOWLEDGE, RANKED_REALLIFE (nil bei alten Backends)
    var mode: String? = nil
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

    /// Datenschutzerklärung (öffentlich, ohne Login; liefert das Dashboard aus)
    static var privacyPolicyURL: URL { cloudBaseURL.appendingPathComponent("datenschutz.html") }

    /// Wer verbunden ist, ergibt sich aus dem Login-Token (Authorization-Header), nicht aus der URL.
    static func gameWebSocketURL() -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components.path = "/ws/game"
        return components.url!
    }
}




