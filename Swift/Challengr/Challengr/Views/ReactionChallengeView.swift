import SwiftUI

/// Reaktions-Test: 3 Runden – Bildschirm rot, dann grün: sofort tippen. Zu früh = Strafzeit.
/// Wer im Schnitt schneller ist, gewinnt. Beide bekommen dieselben Wartezeiten.
struct ReactionChallengeView: View {
    let battleId: Int64
    let socket: GameSocketService
    let onClose: () -> Void

    enum Phase: Equatable { case waiting, go, tooEarly, result(Double), done }

    @State private var round = 0
    @State private var phase: Phase = .waiting
    @State private var times: [Double] = []
    @State private var goAt: Date?
    @State private var task: Task<Void, Never>?
    @State private var sent = false

    private var delays: [Double] { ChallengeSeed.reactionDelays(battleId: battleId) }

    private var color: Color {
        switch phase {
        case .waiting: return .challengrRed
        case .go: return .challengrGreen
        case .tooEarly: return .orange
        case .result, .done: return .challengrDark
        }
    }

    var body: some View {
        ZStack {
            color.ignoresSafeArea()
            VStack(spacing: 18) {
                Text("REAKTIONS-TEST · RUNDE \(min(round + 1, ReactionRules.rounds))/\(ReactionRules.rounds)")
                    .font(.system(size: 14, weight: .black, design: .rounded)).tracking(1.5)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                switch phase {
                case .waiting:
                    big("WARTE …", sub: "Tippe erst, wenn es grün wird")
                case .go:
                    big("JETZT!", sub: "Tippen!")
                case .tooEarly:
                    big("ZU FRÜH!", sub: "+\(Int(ReactionRules.penaltyMs)) ms Strafe")
                case .result(let ms):
                    big("\(Int(ms)) ms", sub: ms < 300 ? "Blitzschnell!" : "Weiter geht's …")
                case .done:
                    VStack(spacing: 10) {
                        Text("DEIN SCHNITT").font(.system(size: 14, weight: .black, design: .rounded)).foregroundColor(GameStyle.secondaryText)
                        Text("\(Int(ReactionRules.average(times))) ms")
                            .font(.system(size: 56, weight: .black, design: .rounded)).foregroundColor(.challengrYellow)
                        Text(times.map { "\(Int($0))" }.joined(separator: " · ") + " ms")
                            .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.8))
                    }
                }
                Spacer()
            }
            .padding(.top, 30)
        }
        // die ganze Fläche ist der Knopf
        .contentShape(Rectangle())
        .onTapGesture { tap() }
        .accessibilityAddTraits(.isButton)
        .onAppear { startRound() }
        .onDisappear { task?.cancel() }
    }

    private func big(_ title: String, sub: String) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.system(size: 60, weight: .black, design: .rounded)).foregroundColor(.white)
            Text(sub).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.85))
        }
    }

    private func startRound() {
        phase = .waiting
        goAt = nil
        let delay = delays[round]
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, phase == .waiting else { return }
            phase = .go
            goAt = Date()
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            // nicht getippt → Strafzeit
            try? await Task.sleep(for: .milliseconds(Int(ReactionRules.maxWaitMs)))
            guard !Task.isCancelled, phase == .go else { return }
            finishRound(ReactionRules.penaltyMs)
        }
    }

    private func tap() {
        switch phase {
        case .waiting:
            task?.cancel()
            phase = .tooEarly
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            times.append(ReactionRules.penaltyMs)
            next(after: 1.2)
        case .go:
            task?.cancel()
            finishRound(Date().timeIntervalSince(goAt ?? Date()) * 1000)
        default:
            break
        }
    }

    private func finishRound(_ ms: Double) {
        if phase == .go {
            times.append(ms)
            phase = .result(ms)
            SoundManager.shared.play(.click)
        }
        next(after: 1.0)
    }

    private func next(after seconds: Double) {
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            round += 1
            if round < ReactionRules.rounds {
                startRound()
            } else {
                phase = .done
                try? await Task.sleep(for: .seconds(2.5))
                guard !sent else { return }
                sent = true
                socket.sendMetricResult(type: "reaction-result", battleId: battleId, field: "ms", value: ReactionRules.average(times))
                onClose()
            }
        }
    }
}
