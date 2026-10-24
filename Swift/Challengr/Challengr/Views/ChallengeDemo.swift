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
