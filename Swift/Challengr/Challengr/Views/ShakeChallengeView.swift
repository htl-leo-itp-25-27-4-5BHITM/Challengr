import SwiftUI

enum ShakePhase {
    case ready
    case running
    case cooldown
    case finished
}

struct ShakeChallengeView: View {
    // MARK: - Input (Eingaben)
    let battleId: Int64
    let socket: GameSocketService
    let onClose: () -> Void

    // MARK: - State (State)
    @StateObject private var motion = MotionManager()

    @State private var phase: ShakePhase = .ready
    @State private var countdown: Int = 3
    @State private var phaseTimer: Timer?

    // MARK: - Derived values (Abgeleitete Werte)

    private var phaseTitle: String {
        switch phase {
        case .ready:
            return "BEREIT MACHEN"
        case .running:
            return "SHAKE CHALLENGE"
        case .cooldown:
            return "ERGEBNIS WIRD BERECHNET"
        case .finished:
            return "FERTIG"
        }
    }

    // MARK: - Body (UI-Aufbau)

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("SHAKE CHALLENGE")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text(phaseTitle)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Text("\(countdown)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(phase == .running && countdown <= 3 ? .red : .white)
                    .animation(.easeInOut, value: countdown)

                VStack(spacing: 10) {
                    Text("SHAKE SCORE")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))

                    Text(String(format: "%.1f", motion.score))
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.challengrYellow)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)

                Spacer()

                if phase == .ready {
                    Text("Schüttle dein iPhone so schnell du kannst – gleich geht's los!")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if phase == .running {
                    Text("10 Sekunden – gib Vollgas!")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                } else if phase == .cooldown {
                    Text("Deine Shakes werden mit deinem Gegner verglichen …")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if phase == .finished {
                    Button(action: onClose) {
                        Text("Zurück zur Map")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.challengrDark)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .background(Color.challengrYellow)
                            .clipShape(Capsule())
                    }
                }

                Spacer()
            }
            .padding()
        }
        .onAppear { startChallenge() }
        .onDisappear {
            motion.stopMeasuring()
            phaseTimer?.invalidate()
        }
    }

    // MARK: - Challenge flow (Ablauf)

    private func startChallenge() {
        phase = .ready
        countdown = 3
    motion.score = 0

        startPhaseTimer(duration: 3) {
            phase = .running
            countdown = 10
            motion.startMeasuring()

            startPhaseTimer(duration: 10) {
                motion.stopMeasuring()
                phase = .cooldown
                countdown = 0

                socket.sendShakeResult(battleId: battleId, shakes: Int(motion.score))
            }
        }
    }

    private func startPhaseTimer(duration: Int, completion: @escaping () -> Void) {
        phaseTimer?.invalidate()
        var remaining = duration
        countdown = remaining

        phaseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            remaining -= 1
            DispatchQueue.main.async {
                countdown = remaining
                if remaining <= 0 {
                    phaseTimer?.invalidate()
                    completion()
                }
            }
        }
    }

    // MARK: - Motion handling (Bewegung)
}

#Preview {
    ShakeChallengeView(battleId: 1, socket: GameSocketService(playerId: 1), onClose: {})
}
