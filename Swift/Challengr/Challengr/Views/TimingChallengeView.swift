import SwiftUI

/// Zeitgefühl: Start tippen, nach genau X Sekunden Stopp tippen – ohne Uhr. Wer näher dran ist, gewinnt.
struct TimingChallengeView: View {
    let battleId: Int64
    let socket: GameSocketService
    let onClose: () -> Void

    enum Phase { case ready, running, result }

    @State private var phase: Phase = .ready
    @State private var startedAt: Date?
    @State private var elapsed: Double = 0
    @State private var pulse = false
    @State private var sent = false
    @State private var autoStop: Task<Void, Never>?

    private var target: Int { ChallengeSeed.timingTarget(battleId: battleId) }

    var body: some View {
        ZStack {
            GameStyle.background.ignoresSafeArea()
            VStack(spacing: 22) {
                Text("ZEITGEFÜHL")
                    .font(.system(size: 15, weight: .black, design: .rounded)).tracking(2)
                    .foregroundColor(.challengrYellow)
                Text("Stoppe bei")
                    .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(GameStyle.secondaryText)
                Text("\(target),00 s")
                    .font(.system(size: 64, weight: .black, design: .rounded)).foregroundColor(.white)
                Spacer()
                switch phase {
                case .ready:
                    Text("Tippe auf Start. Die Uhr läuft unsichtbar – tippe Stopp, wenn du glaubst, dass \(target) Sekunden um sind.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85)).multilineTextAlignment(.center).padding(.horizontal, 28)
                    roundButton("START", color: .challengrGreen) { start() }
                case .running:
                    Text("Zähl im Kopf mit …")
                        .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.85))
                    roundButton("STOPP", color: .challengrRed) { stop() }
                        .scaleEffect(pulse ? 1.04 : 0.98)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                case .result:
                    let off = abs(elapsed - Double(target))
                    VStack(spacing: 8) {
                        Text(String(format: "%.2f s", elapsed))
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundColor(off < 0.3 ? .challengrGreen : .challengrYellow)
                        Text(String(format: "%.2f s daneben", off))
                            .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.white)
                    }
                }
                Spacer()
            }
            .padding(.top, 40)
        }
        .onDisappear { autoStop?.cancel() }
    }

    private func roundButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 190, height: 190)
                .background(Circle().fill(color))
                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 4))
                .shadow(color: color.opacity(0.6), radius: 18)
        }
        .buttonStyle(.plain)
    }

    private func start() {
        SoundManager.shared.play(.click)
        startedAt = Date()
        phase = .running
        pulse = true
        // wer gar nicht stoppt: nach der dreifachen Zielzeit automatisch
        autoStop = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Double(target) * 3))
            guard !Task.isCancelled, phase == .running else { return }
            stop()
        }
    }

    private func stop() {
        guard phase == .running, let startedAt else { return }
        autoStop?.cancel()
        elapsed = Date().timeIntervalSince(startedAt)
        phase = .result
        SoundManager.shared.play(.countdownGo)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let deviationMs = abs(elapsed - Double(target)) * 1000
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !sent else { return }
            sent = true
            socket.sendMetricResult(type: "timing-result", battleId: battleId, field: "ms", value: deviationMs)
            onClose()
        }
    }
}
