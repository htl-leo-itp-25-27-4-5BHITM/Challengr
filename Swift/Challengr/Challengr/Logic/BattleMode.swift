import SwiftUI

/// Spielmodus eines Battles – gleiche Werte wie im Backend (`BattleMode`).
enum BattleMode: String, CaseIterable, Identifiable {
    /// Es geht um nichts: Kategorie und Challenge frei wählbar.
    case friendly = "FRIENDLY"
    /// Liga, Wissen: Quiz-Show mit 4 Fragen.
    case rankedKnowledge = "RANKED_KNOWLEDGE"
    /// Liga, Real-Life: zufällige vom Handy gemessene Challenge.
    /// Beide Liga-Modi spielen um dieselben Trophäen.
    case rankedRealLife = "RANKED_REALLIFE"

    var id: String { rawValue }

    /// Unbekannt oder fehlend (alte Server) → Friendly.
    init(serverValue: String?) {
        self = serverValue.flatMap(BattleMode.init(rawValue:)) ?? .friendly
    }

    var isRanked: Bool { self != .friendly }

    var title: String {
        switch self {
        case .friendly:        return "Friendly"
        case .rankedKnowledge: return "Liga · Quiz-Show"
        case .rankedRealLife:  return "Liga · Real-Life"
        }
    }

    /// Name innerhalb der Liga-Auswahl ("Quiz-Show" / "Real-Life-Challenge")
    var shortTitle: String {
        switch self {
        case .friendly:        return "Friendly"
        case .rankedKnowledge: return "Quiz-Show"
        case .rankedRealLife:  return "Real-Life-Challenge"
        }
    }

    var subtitle: String {
        switch self {
        case .friendly:        return "Es geht um nichts – du wählst die Challenge"
        case .rankedKnowledge: return "Quiz-Show · 4 Fragen · Tempo zählt"
        case .rankedRealLife:  return "Zufällige Handy-Challenge · gemessen"
        }
    }

    var icon: String {
        switch self {
        case .friendly:        return "hand.wave.fill"
        case .rankedKnowledge: return "brain.head.profile"
        case .rankedRealLife:  return "figure.run"
        }
    }

    var color: Color {
        switch self {
        case .friendly:        return .challengrGreen
        case .rankedKnowledge: return .purple
        case .rankedRealLife:  return .challengrRed
        }
    }

    /// Text für die Trophäen-Änderung auf dem Ergebnis-Screen.
    func trophyText(delta: Int) -> String {
        switch self {
        case .friendly:        return "Friendly – es ging um nichts"
        case .rankedKnowledge, .rankedRealLife: return "\(delta >= 0 ? "+" : "")\(delta) Trophäen"
        }
    }
}
