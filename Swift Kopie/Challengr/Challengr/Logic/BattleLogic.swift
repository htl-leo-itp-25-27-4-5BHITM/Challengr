//
//  BattleLogic.swift
//  Challengr
//
//  Pure battle rules used by the views (testbar ohne UI).
//

import Foundation

// MARK: - Result (Ergebnis)

extension BattleResultData {

    /// Is this result meant for us? (Gehört das Ergebnis zu unserem Battle?)
    /// - With player ids from the backend: only if we are winner or loser.
    /// - Without ids (draw / conflict / old backend): only if it is our current battle.
    func isRelevant(ownPlayerId: String, currentBattleId: Int64?) -> Bool {
        let ids = [winnerId, loserId].compactMap { $0 }
        if !ids.isEmpty {
            return ids.contains(ownPlayerId)
        }
        if let battleId, let currentBattleId {
            return battleId == currentBattleId
        }
        return true
    }

    /// Nobody won and nobody lost points (z.B. beide falsch im Wissens-Battle).
    var isDraw: Bool {
        if let outcome { return outcome == "DRAW" }
        return winnerId == nil && loserId == nil && trashTalk == "Unentschieden!"
    }

    /// Did we win? Uses the id when available – names can be identical.
    func didWin(ownPlayerId: String, ownPlayerName: String) -> Bool {
        if let winnerId {
            return winnerId == ownPlayerId
        }
        // Unentschieden/Konflikt: niemand hat gewonnen (auch wenn jemand "Niemand" heißt)
        if isDraw || outcome == "CONFLICT" { return false }
        return winnerName == ownPlayerName
    }
}

// MARK: - Voting (Abstimmung)

extension VoteSide {
    /// playerA is always the own player, playerB the opponent.
    func winner(ownId: String, ownName: String, opponentId: String, opponentName: String) -> (id: String, name: String) {
        switch self {
        case .playerA: return (ownId, ownName)
        case .playerB: return (opponentId, opponentName)
        }
    }
}

// MARK: - Challenge lookup (Challenge auflösen)

enum ChallengeResolver {

    struct Resolved {
        let name: String
        let category: String
        /// Set when the challenge had to be loaded from the backend (for the local cache).
        let fetched: ChallengeDTO?
    }

    /// Order: text from backend payload → local cache → load by id. Never guesses.
    static func resolve(
        id: Int64,
        text: String?,
        category: String?,
        cached: [ChallengeDTO],
        fetch: (Int64) async throws -> ChallengeDTO
    ) async -> Resolved {
        if let text, !text.isEmpty, let category, !category.isEmpty {
            return Resolved(name: text, category: category, fetched: nil)
        }
        if let ch = cached.first(where: { $0.id == id }) {
            return Resolved(name: ch.text, category: ch.category, fetched: nil)
        }
        if let ch = try? await fetch(id) {
            return Resolved(name: ch.text, category: ch.category, fetched: ch)
        }
        return Resolved(name: "Challenge \(id)", category: "Unbekannt", fetched: nil)
    }
}

// MARK: - Challenge picking (Zufällige Challenge wählen)

enum ChallengePicker {

    static func normalized(_ category: String) -> String {
        category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// All challenges of a category (Groß-/Kleinschreibung und Leerzeichen egal).
    static func challenges(in category: String, from all: [ChallengeDTO]) -> [ChallengeDTO] {
        let wanted = normalized(category)
        return all.filter { normalized($0.category) == wanted }
    }

    static func random(in category: String, from all: [ChallengeDTO]) -> ChallengeDTO? {
        challenges(in: category, from: all).randomElement()
    }
}

// MARK: - Incoming requests (BUG-02 / BUG-05)

/// What the app does with a "battle-requested" message.
enum ChallengeRoute: Equatable {
    /// Someone challenges us – show the popup.
    case incoming
    /// Our own request (also re-sent after a reconnect) – show "Anfrage gesendet".
    case outgoing
    /// Someone challenges us while we are in a battle – decline automatically.
    case declineBusy
    /// Not our business.
    case ignore
}

enum ChallengeRouter {
    static func route(fromId: String, toId: String, ownPlayerId: String, isInBattle: Bool) -> ChallengeRoute {
        if toId == ownPlayerId { return isInBattle ? .declineBusy : .incoming }
        if fromId == ownPlayerId { return .outgoing }
        return .ignore
    }

    /// Which of our pending requests did the server just mark as accepted?
    static func acceptedRequest(battleId: Int64, incomingId: Int64?, outgoingId: Int64?) -> ChallengeRoute {
        if battleId == incomingId { return .incoming }
        if battleId == outgoingId { return .outgoing }
        return .ignore
    }
}

extension BattleHistoryDTO {
    /// Beendet, aber ohne Gewinner (z.B. beide falsch im Wissens-Battle).
    var isDraw: Bool { !won && status == "DONE" && (winnerName ?? "").isEmpty && pointsDelta == 0 }
}
