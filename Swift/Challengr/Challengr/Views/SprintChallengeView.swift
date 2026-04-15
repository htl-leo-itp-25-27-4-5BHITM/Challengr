//
//  SprintPhase.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 16.03.26.
//


import SwiftUI
import CoreLocation

enum SprintPhase {
    case ready       // 10s Vorbereitung
    case running     // 15s Sprint
    case cooldown    // 5s „Ergebnis wird berechnet“
    case finished
}

struct SprintChallengeView: View {
    // MARK: - Input (Eingaben)
    let battleId: Int64
    let playerId: Int64
    let playerName: String
    let socket: GameSocketService
    let onClose: () -> Void

    // MARK: - State (State)
    @StateObject private var locationHelper: LocationHelper

    @State private var phase: SprintPhase = .ready
    @State private var countdown: Int = 10        // Start mit 10s Vorbereitung
    @State private var startLocation: CLLocationCoordinate2D?
    @State private var maxDistance: CLLocationDistance = 0
    @State private var timer: Timer?

    // MARK: - Derived values (Abgeleitete Werte)

    private var phaseTitle: String {
        switch phase {
        case .ready:    return "BEREIT MACHEN"
        case .running:  return "SPRINT LÄUFT"
        case .cooldown: return "ERGEBNIS WIRD BERECHNET"
        case .finished: return "FERTIG"
        }
    }

    private var distanceText: String {
        String(format: "%.1f m", maxDistance)
    }

    // MARK: - Init
    init(battleId: Int64, playerId: Int64, playerName: String, socket: GameSocketService, onClose: @escaping () -> Void) {
        self.battleId = battleId
        self.playerId = playerId
        self.playerName = playerName
        self.socket = socket
        self.onClose = onClose
        _locationHelper = StateObject(wrappedValue: LocationHelper(playerId: playerId, playerName: playerName))
    }

    // MARK: - Body (UI-Aufbau)

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("SPRINT CHALLENGE")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text(phaseTitle)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Text("\(countdown)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(phase == .running && countdown <= 3 ? .red : .white)
                    .animation(.easeInOut, value: countdown)

                VStack(spacing: 6) {
                    Text("DEINE DISTANZ")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))

                    Text(distanceText)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.challengrYellow)
                }

                Spacer()

                if phase == .ready {
                    Text("In \(countdown) Sekunden geht der Sprint los – bereit machen!")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if phase == .running {
                    Text("Lauf so weit du kannst!")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                } else if phase == .cooldown {
                    Text("Deine Meter werden mit deinem Gegner verglichen …")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if phase == .finished {
                    // Optional: Button, falls der Win/Lose-Screen nicht automatisch öffnet
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
            }
            .padding(24)
        }
        .onAppear {
            startReadyPhase()
        }
        .onReceive(locationHelper.$userLocation) { loc in
            handleLocationUpdate(loc)
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
}

// MARK: - Actions (Aktionen)

private extension SprintChallengeView {
    func startReadyPhase() {
        phase = .ready
        countdown = 10

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            readyTick()
        }
    }

    func readyTick() {
        if countdown > 0 {
            countdown -= 1
        } else {
            startRunningPhase()
        }
    }

    func startRunningPhase() {
        phase = .running
        countdown = 15
        maxDistance = 0

        if let loc = locationHelper.userLocation {
            startLocation = loc
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            runningTick()
        }
    }

    func runningTick() {
        if countdown > 0 {
            countdown -= 1
        } else {
            startCooldownPhase()
        }
    }

    func startCooldownPhase() {
        phase = .cooldown
        countdown = 5

        print("🏁 Sprint fertig, sende Distanz:", maxDistance)   // <‑ Debug
        socket.sendSprintResult(battleId: battleId, distance: maxDistance)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            cooldownTick()
        }
    }


    func cooldownTick() {
        if countdown > 0 {
            countdown -= 1
        } else {
            phase = .finished
            timer?.invalidate()
            // Ab hier kommt irgendwann battle-result vom Server,
            // dein bestehender Flow öffnet Win/Lose.
        }
    }

    func handleLocationUpdate(_ newLoc: CLLocationCoordinate2D?) {
        guard phase == .running,
              let start = startLocation,
              let loc = newLoc else { return }

        let startCL = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let curCL   = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        let d = startCL.distance(from: curCL)

        if d > maxDistance {
            maxDistance = d
        }
    }
}
