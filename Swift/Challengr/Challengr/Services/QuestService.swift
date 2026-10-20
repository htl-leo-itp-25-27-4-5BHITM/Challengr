import Foundation

/// Eine Aufgabe (täglich oder als Teil eines Events).
struct QuestTask: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let target: Int
    let progress: Int
    let coins: Int
    let claimed: Bool

    var done: Bool { progress >= target }
    var fraction: Double { target == 0 ? 1 : min(1, Double(progress) / Double(target)) }
}

/// Zeitlich begrenztes Event (z. B. Beta, Halloween) mit Figur als Belohnung.
struct QuestEvent: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let startsOn: String
    let endsOn: String
    let active: Bool
    let rewardCharacter: String?
    let rewardCoins: Int
    let tasks: [QuestTask]
    let completed: Bool
    let claimed: Bool

    var character: GameCharacter? { GameCharacter.from(serverId: rewardCharacter) }
    var doneCount: Int { tasks.filter(\.done).count }

    /// Letzter Tag (inklusive) als Datum, Wiener Zeit.
    var endDate: Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
        let parts = endsOn.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2] + 1))
    }
}

/// Alles für die Aufgaben-Ansicht (vom Server).
struct QuestBoard: Codable, Equatable {
    let coins: Int
    let day: String
    let resetsAt: String
    let daily: [QuestTask]
    let events: [QuestEvent]

    /// Wie viele Belohnungen gerade abholbereit sind (Zahl am Menü-Knopf).
    var claimable: Int {
        daily.filter { $0.done && !$0.claimed }.count + events.filter { $0.completed && !$0.claimed }.count
    }

    var resetDate: Date? { ISO8601DateFormatter().date(from: resetsAt) }
}

final class QuestService {
    private let baseURL = BackendConfig.apiURL("api/quests")

    func load() async throws -> QuestBoard {
        let (data, _) = try await API.data(from: baseURL)
        return try JSONDecoder().decode(QuestBoard.self, from: data)
    }

    func claimDaily(_ taskId: String) async throws -> QuestBoard {
        try await post(baseURL.appendingPathComponent("daily").appendingPathComponent(taskId).appendingPathComponent("claim"))
    }

    func claimEvent(_ eventId: String) async throws -> QuestBoard {
        try await post(baseURL.appendingPathComponent("events").appendingPathComponent(eventId).appendingPathComponent("claim"))
    }

    private func post(_ url: URL) async throws -> QuestBoard {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await API.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(QuestBoard.self, from: data)
    }
}
