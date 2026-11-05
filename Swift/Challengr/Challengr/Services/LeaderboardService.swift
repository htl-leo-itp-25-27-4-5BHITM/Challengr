import Foundation

/// Eine Zeile der Rangliste (vom Backend, nie mit Standort).
struct LeaderboardRow: Codable, Identifiable, Equatable {
    let place: Int
    let playerId: String
    let name: String
    let trophies: Int
    let rankName: String
    var character: String? = nil
    let me: Bool

    var id: String { playerId }
}

/// Top 10 aller Spieler, Freunde (inkl. einem selbst) und der eigene Platz.
struct Leaderboard: Codable, Equatable {
    let school: [LeaderboardRow]
    let friends: [LeaderboardRow]
    let me: LeaderboardRow?
    let totalPlayers: Int

    /// Eigener Platz ist schon in der Top 10 zu sehen – dann keine extra Zeile darunter.
    var meIsInTop: Bool { school.contains { $0.me } }
}

final class LeaderboardService {
    func load() async throws -> Leaderboard {
        let (data, _) = try await API.data(from: BackendConfig.apiURL("api/leaderboard"))
        return try JSONDecoder().decode(Leaderboard.self, from: data)
    }
}
