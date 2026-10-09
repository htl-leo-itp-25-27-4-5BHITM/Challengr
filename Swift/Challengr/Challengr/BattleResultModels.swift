import Foundation

struct BattleMetricPair<T> {
    let winner: T
    let loser: T
}

struct BattleMetrics {
    let sprint: BattleMetricPair<Double>?
    let loudness: BattleMetricPair<Double>?
    let compass: BattleMetricPair<Double>?
    let shake: BattleMetricPair<Int>?
    let pushup: BattleMetricPair<Int>?
}

struct BattleResultData {
    let winnerName: String
    let winnerAvatar: String   // später: Bildname
    let winnerPointsDelta: Int

    let loserName: String
    let loserAvatar: String
    let loserPointsDelta: Int

    let trashTalk: String      // nur im Lose-Screen angezeigt
    let metrics: BattleMetrics?

    /// Set by the backend; nil for old backends or a draw/conflict (kein Gewinner).
    var battleId: Int64? = nil
    var winnerId: String? = nil
    var loserId: String? = nil
    /// "WIN", "DRAW" oder "CONFLICT" (nil bei alten Backends).
    var outcome: String? = nil
    /// Beide Spieler mit Name und Figur (nil bei alten Backends).
    var participants: BattleParticipants? = nil
    /// Liga oder Friendly
    var mode: BattleMode = .friendly
    /// Endstand der Quiz-Show (nur Liga Wissen)
    var quizFromScore: Int? = nil
    var quizToScore: Int? = nil

    /// "+28 🏆" in der Liga, im Friendly nur "–" (es geht um nichts).
    func deltaLabel(_ delta: Int) -> String {
        mode.isRanked ? "\(delta >= 0 ? "+" : "")\(delta) 🏆" : "FRIENDLY"
    }

    /// "Basti 320 : 210 Mia" – Endstand der Quiz-Show, nil außerhalb der Liga Wissen.
    var quizScoreLine: String? {
        guard let from = quizFromScore, let to = quizToScore else { return nil }
        let fromName = participants?.fromName ?? "Herausforderer"
        let toName = participants?.toName ?? "Gegner"
        return "\(fromName) \(from) : \(to) \(toName)"
    }
}

/// Beide Spieler eines Battles mit Name und Figur (vom Backend in battle-requested/-running/-result).
struct BattleParticipants: Equatable {
    let fromId: String
    let toId: String
    var fromName: String? = nil
    var toName: String? = nil
    var fromCharacter: GameCharacter? = nil
    var toCharacter: GameCharacter? = nil

    /// Aus einer Backend-Nachricht; nil, wenn die Spieler-Ids fehlen (alte Backends).
    static func parse(_ json: [String: Any], fromKey: String = "fromPlayerId", toKey: String = "toPlayerId") -> BattleParticipants? {
        func id(_ value: Any?) -> String? {
            if let s = value as? String, !s.isEmpty { return s }
            if let n = value as? NSNumber { return n.stringValue }
            return nil
        }
        guard let from = id(json[fromKey]), let to = id(json[toKey]) else { return nil }
        func name(_ key: String) -> String? { (json[key] as? String).flatMap { $0.isEmpty ? nil : $0 } }
        return BattleParticipants(
            fromId: from,
            toId: to,
            fromName: name("fromName"),
            toName: name("toName"),
            fromCharacter: GameCharacter.from(serverId: json["fromCharacter"] as? String),
            toCharacter: GameCharacter.from(serverId: json["toCharacter"] as? String)
        )
    }

    func opponentId(ownId: String) -> String { fromId == ownId ? toId : fromId }
    func opponentName(ownId: String) -> String? { fromId == ownId ? toName : fromName }
    func opponentCharacter(ownId: String) -> GameCharacter? { fromId == ownId ? toCharacter : fromCharacter }
}

/// Zusatzinfos zu einem laufenden Battle nach einem Neustart.
struct RunningBattleExtras: Equatable {
    var targetLatitude: Double? = nil
    var targetLongitude: Double? = nil
    /// Hat man sein Ergebnis/seine Stimme schon abgegeben? Dann nur noch aufs Ergebnis warten.
    var submitted = false
}

extension BattleResultData {
    /// Figur zu einem Spielernamen auf den Ergebnis-Karten.
    /// Mit Backend-Daten die echte Figur, sonst eigene Figur bzw. Ersatz-Figur für den Gegner.
    func character(forPlayerName name: String, ownPlayerName: String) -> GameCharacter {
        if let p = participants {
            if name == p.fromName, let c = p.fromCharacter { return c }
            if name == p.toName, let c = p.toCharacter { return c }
        }
        return name == ownPlayerName ? GameCharacter.current : GameCharacter.opponent
    }

    /// Bei Konflikt/Unentschieden schickt das Backend "Niemand" als Namen – hier die echten.
    func playerNames(ownPlayerName: String) -> (own: String, opponent: String)? {
        guard let p = participants, let from = p.fromName, let to = p.toName else { return nil }
        return from == ownPlayerName ? (from, to) : (to, from)
    }
}
