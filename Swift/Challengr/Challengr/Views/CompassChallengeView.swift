//
//  CompassChallengeView.swift
//  Challengr
//
//  Small compass accuracy challenge adapted from external project.
//

import SwiftUI
import CoreLocation
import Combine

struct CompassChallengeView: View {

    // Inputs
    let battleId: Int64
    let playerId: Int64
    let socket: GameSocketService
    let onClose: () -> Void

    @StateObject private var compass = CompassManager()

    enum Phase { case ready, running, preview }
    @State private var phase: Phase = .ready
    // preparatory countdown (show own heading)
    @State private var prepCountdown: Int = 10
    // running countdown (hide own heading, show target)
    @State private var runCountdown: Int = 10
    // Target is fixed to 0° per requirement
    @State private var targetHeading: Int = 0
    @State private var frozenHeading: Double? = nil
    @State private var previewCountdown: Int = 3
    @State private var resultDistance: Double = 0
    @State private var hasSentResult: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("🧭 COMPASS CHALLENGE")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text(phaseTitle)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                // Show heading only during the initial alignment countdown
                if phase == .ready {
                    Text("\(Int(compass.heading))°")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundColor(.challengrYellow)
                } else {
                    // hide heading while running/result — show masked placeholder
                    Text("—°")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }

                if phase == .ready {
                    Text("Richte dich auf 0° aus")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))

                    Text("\(prepCountdown)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }

                if phase == .running {
                    VStack(spacing: 10) {
                        Text("ZIELWINKEL")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))

                        Text("\(targetHeading)°")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(.challengrYellow)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 22)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.challengrYellow.opacity(0.45), lineWidth: 1.5)
                            )

                        Text("Noch \(runCountdown) Sekunden")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                }

                if phase == .preview {
                    VStack(spacing: 12) {
                        Text("DEIN ERGEBNIS")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))

                        Text("\(Int(frozenHeading ?? compass.heading))°")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("Ziel: \(targetHeading)°")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.challengrYellow)

                        Text("Abstand: \(Int(resultDistance.rounded()))°")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.challengrYellow)

                        Text("Sende in \(previewCountdown)s …")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.challengrYellow.opacity(0.25), lineWidth: 1)
                    )
                }

                Spacer()

            }
            .padding()
        }
        .onAppear { startChallenge() }
        .onDisappear {
            hasSentResult = true
        }
    }

    private var phaseTitle: String {
        switch phase {
        case .ready: return "BEREIT MACHEN"
        case .running: return "DREHEN"
        case .preview: return "ERGEBNIS"
        }
    }

    private func startChallenge() {
        phase = .ready
        prepCountdown = 10
        runCountdown = 10
        targetHeading = 0

        // Prep phase: show own heading for prepCountdown seconds
        Task {
            while prepCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                prepCountdown -= 1
            }

            // Reveal a random target when running starts
            targetHeading = Int.random(in: 0..<360)
            phase = .running

            // Running: player must orient without seeing own heading
            while runCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                runCountdown -= 1
            }

            // Freeze heading and compute result first
            frozenHeading = compass.heading
            let current = Int(frozenHeading ?? compass.heading)
            let angularDist = abs(Double(current) - Double(targetHeading))
            let normalized = min(angularDist, 360 - angularDist)
            resultDistance = normalized

            // Show own result for 3 seconds before sending
            previewCountdown = 3
            phase = .preview
            while previewCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                previewCountdown -= 1
            }

            // Send only once and close challenge so the existing pending overlay can be used
            guard !hasSentResult else { return }
            hasSentResult = true
            socket.sendCompassResult(battleId: battleId, distance: normalized)
            onClose()
        }
    }
}

// Reuse CompassManager from external snippet
final class CompassManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var heading: Double = 0.0

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.heading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        }
    }
}

// Preview
struct CompassChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        CompassChallengeView(battleId: 1, playerId: 1, socket: GameSocketService(playerId: 1), onClose: {})
    }
}
