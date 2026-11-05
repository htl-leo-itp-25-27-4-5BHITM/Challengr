#if DEBUG
import SwiftUI

/// Nur Entwickler-Builds: eine Challenge samt Erklär-Bildschirm ohne Gegner starten (AUDIT_CHALLENGE_DEMO=reaction|timing|country|compass|shake).
struct ChallengeDemo: View {
    let kind: String
    private let socket = GameSocketService(playerId: "demo")
    @State private var closed = false

    private var screen: BattleScreen {
        switch kind {
        case "timing": return .timing
        case "country": return .country
        case "compass": return .compass
        case "shake": return .shake
        default: return .reaction
        }
    }

    var body: some View {
        if closed {
            Text("CHALLENGE BEENDET").font(.largeTitle.bold())
        } else {
            ChallengeIntroGate(intro: ChallengeIntro.for(screen)) {
                switch screen {
                case .timing: TimingChallengeView(battleId: 7, socket: socket, onClose: { closed = true })
                case .country: CountryCompassView(battleId: 7, socket: socket, position: nil, onClose: { closed = true })
                case .compass: CompassChallengeView(battleId: 7, playerId: "demo", socket: socket, onClose: { closed = true })
                case .shake: ShakeChallengeView(battleId: 7, socket: socket, onClose: { closed = true })
                default: ReactionChallengeView(battleId: 7, socket: socket, onClose: { closed = true })
                }
            }
        }
    }
}
#endif

#if DEBUG
import SwiftUI

/// Nur Entwickler-Builds: Ergebnis-Bildschirm ohne Battle (AUDIT_RESULT_DEMO=win|lose|draw|friendly).
struct ResultDemo: View {
    let kind: String
    @State private var round = 0

    var body: some View {
        BattleResultView(data: data, ownPlayerName: "Basti", ownWins: kind == "win" || kind == "friendly") {
            round += 1   // "Weiter" spielt die Animation erneut ab
        }
        .id(round)
    }

    private var data: BattleResultData {
        let ownWins = kind == "win" || kind == "friendly"
        var d = BattleResultData(
            winnerName: ownWins ? "Basti" : "Mia", winnerAvatar: "", winnerPointsDelta: kind == "draw" ? 0 : 28,
            loserName: ownWins ? "Mia" : "Basti", loserAvatar: "", loserPointsDelta: kind == "draw" ? 0 : -20,
            trashTalk: "Nächstes Mal vielleicht mit Aufwärmen?",
            metrics: BattleMetrics(sprint: nil, loudness: nil, compass: nil, shake: nil, pushup: nil, reaction: BattleMetricPair(winner: 212, loser: 305)))
        d.outcome = kind == "draw" ? "DRAW" : "WIN"
        d.mode = kind == "friendly" ? .friendly : .rankedRealLife
        d.participants = BattleParticipants(fromId: "a", toId: "b", fromName: "Basti", toName: "Mia",
                                            fromCharacter: .junge, toCharacter: .maedchen)
        return d
    }
}
#endif
