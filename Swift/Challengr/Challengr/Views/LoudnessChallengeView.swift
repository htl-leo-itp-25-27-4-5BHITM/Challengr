//
//  LoudnessChallengeView.swift
//  Challengr
//
//  Created by Julian Richter on 23.03.26.
//

import SwiftUI

enum LoudnessPhase {
    case ready       // 10s Vorbereitung
    case running     // 10s Loudness wird gemessen
    case cooldown    // 5s „Ergebnis wird berechnet"
    case finished
}

struct LoudnessChallengeView: View {
    let battleId: Int64
    let socket: GameSocketService
    let onClose: () -> Void

    @StateObject private var meter = SoundMeter()

    @State private var phase: LoudnessPhase = .ready
    @State private var countdown: Int = 10        // Start mit 10s Vorbereitung
    @State private var currentPhaseTimer: Timer?

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

                // Loudness Meter während der Running-Phase
                if phase == .running {
                    VStack(spacing: 12) {
                        Text("AKTUELLE LAUTSTÄRKE")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))

                        Text(String(format: "%.1f dB", meter.level))
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.challengrYellow)

                        // Progress Bar für Lautstärke
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
                    // Anzeige des finalen Wertes
                    VStack(spacing: 12) {
                        Text("DEIN ERGEBNIS")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))

                        Text(loudnessText)
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(.challengrYellow)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }

                Spacer()

                if phase == .ready {
                    Text("Bereite dich vor – in \(countdown) Sekunden beginnt die Brüll Challenge!")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
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
        }
    }

    private func startChallenge() {
        phase = .ready
        countdown = 10

        // Phase 1: Ready (10 Sekunden)
        startPhaseTimer(duration: 10) {
            // Phase 2: Running (10 Sekunden)
            phase = .running
            countdown = 10
            
            meter.start()

            startPhaseTimer(duration: 10) {
                meter.stop()

                // Phase 3: Cooldown (5 Sekunden)
                phase = .cooldown
                countdown = 5

                startPhaseTimer(duration: 5) {
                    // Phase 4: Finished
                    phase = .finished
                    countdown = 0

                    // Ergebnis an Backend senden (maxLevel wird automatisch von meter trackt)
                    socket.sendLoudnessResult(battleId: battleId, loudness: Double(meter.maxLevel))

                    // Optional: Nach kurzer Zeit automatisch schließen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        // onClose() wird nicht automatisch aufgerufen, damit User das Ergebnis sehen kann
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
}

#Preview {
    LoudnessChallengeView(
        battleId: 1,
        socket: GameSocketService(playerId: 1),
        onClose: {}
    )
}
