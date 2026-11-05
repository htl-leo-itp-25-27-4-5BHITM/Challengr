import Foundation

/// Ein Punkt im Trophäenverlauf: Stand am Ende eines Tages mit Liga-Battles.
struct TrophyHistoryPoint: Identifiable, Equatable {
    /// "yyyy-MM-dd" bzw. `TrophyHistory.startLabel` für den Stand vor dem ersten Battle
    let date: String
    let trophies: Int

    var id: String { date }
}

/// Trophäenverlauf aus den eigenen Battles – rückwärts vom aktuellen Stand gerechnet,
/// damit er immer zur Anzeige im Profil passt. Friendly-Battles zählen nicht.
enum TrophyHistory {
    static let startLabel = "Start"

    static func daily(battles: [BattleHistoryDTO], current: Int) -> [TrophyHistoryPoint] {
        let league = battles.filter { $0.mode != "FRIENDLY" }
        guard !league.isEmpty else { return [] }
        let deltaByDay = Dictionary(grouping: league) { String($0.createdAt.prefix(10)) }
            .mapValues { $0.reduce(0) { $0 + $1.pointsDelta } }

        var points: [TrophyHistoryPoint] = []
        var running = current
        for day in deltaByDay.keys.sorted(by: >) {
            points.append(TrophyHistoryPoint(date: day, trophies: running))
            running -= deltaByDay[day] ?? 0
        }
        points.append(TrophyHistoryPoint(date: startLabel, trophies: max(running, 0)))
        return points.reversed()
    }
}
