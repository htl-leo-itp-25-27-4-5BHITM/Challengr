import Foundation

/// Wo man auf der Trophy Road steht. Jeder Rang ist ein gleich langes Wegstück (Position 0 = Beginn des
/// ersten Rangs, 1 = Beginn des zweiten …); innerhalb des Rangs wächst die Position mit den Trophäen bis
/// zur Grenze des nächsten Rangs. Der höchste Rang ist nach oben offen (wie im Backend).
struct TrophyRoadMath {
    let ranks: [TrophyRank]

    init(ranks: [TrophyRank]) {
        self.ranks = ranks.sorted { $0.min < $1.min }
    }

    /// Anzahl Wegstücke – das Ziel liegt bei `length`.
    var length: Double { Double(ranks.count) }

    /// Index des Rangs für diesen Stand; unter dem ersten zählt der erste, über dem letzten der letzte.
    func rankIndex(for trophies: Int) -> Int? {
        guard !ranks.isEmpty else { return nil }
        return ranks.lastIndex { trophies >= $0.min } ?? 0
    }

    /// Seit dem letzten Öffnen der Trophy Road einen neuen Rang erreicht? (Noch nie geöffnet → nein.)
    func hasNewRank(lastSeen: Int?, trophies: Int) -> Bool {
        guard let lastSeen, let old = rankIndex(for: lastSeen), let now = rankIndex(for: trophies) else { return false }
        return now > old
    }

    func rank(for trophies: Int) -> TrophyRank? {
        rankIndex(for: trophies).map { ranks[$0] }
    }

    func nextRank(after trophies: Int) -> TrophyRank? {
        guard let i = rankIndex(for: trophies), i + 1 < ranks.count else { return nil }
        return ranks[i + 1]
    }

    /// Trophäen bis zum nächsten Rang (nil = höchster Rang erreicht).
    func trophiesToNextRank(_ trophies: Int) -> Int? {
        nextRank(after: trophies).map { $0.min - trophies }
    }

    /// Position auf dem Weg (0…length).
    func position(for trophies: Int) -> Double {
        guard let i = rankIndex(for: trophies) else { return 0 }
        return Double(i) + progressInRank(trophies)
    }

    /// Fortschritt im aktuellen Rang (0…1). Im höchsten Rang höchstens 0,9 – das Ziel bleibt sichtbar vorn.
    func progressInRank(_ trophies: Int) -> Double {
        guard let i = rankIndex(for: trophies) else { return 0 }
        let rank = ranks[i]
        let into = Double(max(trophies - rank.min, 0))
        if i + 1 < ranks.count {
            return min(into / Double(max(ranks[i + 1].min - rank.min, 1)), 1)
        }
        return min(into / Double(max(rank.max - rank.min, 1)), 1) * 0.9
    }
}

/// Merkt sich pro Spieler, mit welchem Stand die Trophy Road zuletzt angesehen wurde –
/// beim nächsten Öffnen läuft die Figur von dort zum neuen Stand.
enum TrophyRoadMemory {
    static func key(_ playerId: String) -> String { "trophyRoad.lastSeen.\(playerId)" }

    static func lastSeen(playerId: String, defaults: UserDefaults = .standard) -> Int? {
        defaults.object(forKey: key(playerId)) == nil ? nil : defaults.integer(forKey: key(playerId))
    }

    static func remember(_ trophies: Int, playerId: String, defaults: UserDefaults = .standard) {
        defaults.set(trophies, forKey: key(playerId))
    }
}
