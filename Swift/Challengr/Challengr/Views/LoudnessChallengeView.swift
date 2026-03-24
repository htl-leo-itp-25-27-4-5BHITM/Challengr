//
//  LoudnessChallengeView.swift
//  Challengr
//
//  Created by Julian Richter on 23.03.26.
//

import SwiftUI

enum LoudnessPhase {
    case ready      // 10s Vorbereitung
    case running    // 10s Loudness wird gemessen
    case cooldown   // 5s „Ergebnis wird berechnet"
    case finished
}

struct LoudnessSample: Identifiable {
    let id = UUID()
    let time: TimeInterval   // Sekunden seit Start
    let level: Float         // dB
}

struct LoudnessChallengeView: View {
    let battleId: Int64
    let socket: GameSocketService
    let onClose: () -> Void

    @StateObject private var meter = SoundMeter()

    @State private var phase: LoudnessPhase = .ready
    @State private var countdown: Int = 10
    @State private var currentPhaseTimer: Timer?

    // Für Verlauf & Integral
    @State private var startDate: Date?
    @State private var samples: [LoudnessSample] = []
    @State private var sampleTimer: Timer?

    private var phaseTitle: String {
        switch phase {
        case .ready:    return "BEREIT MACHEN"
        case .running:  return "BRÜLL CHALLENGE"
        case .cooldown: return "ERGEBNIS WIRD BERECHNET"
        case .finished: return "FERTIG"
        }
    }

    private var loudnessText: String {
        String(format: "%.1f dB", meter.maxLevel)
    }

    private var loudnessIntegralText: String {
        let value = computeLoudnessIntegral()
        return String(format: "%.1f dB·s", value)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("LOUDNESS CHALLENGE")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text(phaseTitle)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Text("\(countdown)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(phase == .running && countdown <= 3 ? .red : .white)
                    .animation(.easeInOut, value: countdown)

                if phase == .running {
                    VStack(spacing: 12) {
                        Text("AKTUELLE LAUTSTÄRKE")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))

                        Text(String(format: "%.1f dB", meter.level))
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.challengrYellow)

                        let normalizedLevel = max(0, min(1, (meter.level + 60) / 60))

                        ProgressView(value: normalizedLevel)
                            .tint(normalizedLevel < 0.3 ? .green :
                                  normalizedLevel < 0.7 ? .yellow : .red)
                            .scaleEffect(x: 1, y: 4, anchor: .center)
                            .padding()
                            .animation(.linear(duration: 0.05), value: normalizedLevel)

                        Text("MAX: \(loudnessText)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.challengrYellow.opacity(0.8))
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                } else if phase == .finished {
                    VStack(spacing: 12) {
                        Text("DEIN ERGEBNIS")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))

                        Text(loudnessText)
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(.challengrYellow)

                        Text("GESAMTLAUTHEIT (Integral)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))

                        Text(loudnessIntegralText)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.challengrYellow)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }

                // Verlaufsgrafik für running + finished
                if phase == .running || phase == .finished {
                    LoudnessGraphView(samples: samples)
                        .frame(height: 200)
                        .padding(.horizontal)
                }

                Spacer()

                if phase == .ready {
                    Text("Bereite dich vor – in \(countdown) Sekunden beginnt die Brüll Challenge!")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text("Achtung: Zu lautes oder längeres Schreien kann deine Stimme und dein Gehör schädigen. Schreie verantwortungsvoll und brich sofort ab, wenn du Schmerzen hast.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if phase == .running {
                    Text("Schreie so laut du kannst!")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                } else if phase == .cooldown {
                    Text("Deine Lautstärke wird mit deinem Gegner verglichen …")
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
        .onAppear {
            startChallenge()
        }
        .onDisappear {
            meter.stop()
            currentPhaseTimer?.invalidate()
            sampleTimer?.invalidate()
        }
    }

    // MARK: - Challenge Flow

    private func startChallenge() {
        phase = .ready
        countdown = 10
        samples = []
        startDate = nil

        startPhaseTimer(duration: 10) {
            // Phase 2: Running (10 Sekunden)
            phase = .running
            countdown = 10

            startDate = Date()
            samples = []
            meter.start()
            startSampleTimer()

            startPhaseTimer(duration: 10) {
                meter.stop()
                sampleTimer?.invalidate()

                // Phase 3: Cooldown (5 Sekunden)
                phase = .cooldown
                countdown = 5

                startPhaseTimer(duration: 5) {
                    // Phase 4: Finished
                    phase = .finished
                    countdown = 0

                    // Ergebnis an Backend senden
                    let integral = computeLoudnessIntegral()
                    socket.sendLoudnessResult(
                        battleId: battleId,
                        loudness: Double(meter.maxLevel)
                        // ggf. weiteres Feld für Integral ergänzen
                        // loudnessIntegral: integral
                    )

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        // optional auto-close
                    }
                }
            }
        }
    }

    private func startPhaseTimer(duration: Int, completion: @escaping () -> Void) {
        currentPhaseTimer?.invalidate()
        var remaining = duration

        currentPhaseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            remaining -= 1
            DispatchQueue.main.async {
                countdown = remaining
            }

            if remaining <= 0 {
                currentPhaseTimer?.invalidate()
                completion()
            }
        }
    }

    // MARK: - Sampling & Integral

    private func startSampleTimer() {
        sampleTimer?.invalidate()

        sampleTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard phase == .running,
                  let start = startDate else { return }

            let t = Date().timeIntervalSince(start)
            let sample = LoudnessSample(time: t, level: meter.level)
            samples.append(sample)
        }
    }

    private func computeLoudnessIntegral() -> Double {
        guard samples.count >= 2 else { return 0 }

        var area: Double = 0
        for i in 1..<samples.count {
            let dt = samples[i].time - samples[i - 1].time
            let avgLevel = (Double(samples[i].level) + Double(samples[i - 1].level)) / 2.0
            area += avgLevel * dt
        }
        return area // dB * s
    }
}

// MARK: - Graph View

struct LoudnessGraphView: View {
    let samples: [LoudnessSample]

    var body: some View {
        GeometryReader { geo in
            let maxTime = samples.last?.time ?? 1
            let minLevel = (samples.map(\.level).min() ?? -60) - 5
            let maxLevel = (samples.map(\.level).max() ?? 0) + 5

            ZStack {
                // einfache „Achsen“ / Hintergrund
                Color.white.opacity(0.03)

                Path { path in
                    guard let first = samples.first else { return }

                    func point(_ s: LoudnessSample) -> CGPoint {
                        let x = CGFloat(s.time / maxTime) * geo.size.width
                        let yNorm = (CGFloat(s.level) - CGFloat(minLevel)) / CGFloat(maxLevel - minLevel)
                        let y = geo.size.height * (1 - yNorm)
                        return CGPoint(x: x, y: y)
                    }

                    path.move(to: point(first))
                    for s in samples.dropFirst() {
                        path.addLine(to: point(s))
                    }
                }
                .stroke(Color.challengrYellow, lineWidth: 2)
            }
            .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#Preview {
    LoudnessChallengeView(
        battleId: 1,
        socket: GameSocketService(playerId: 1),
        onClose: {}
    )
}
