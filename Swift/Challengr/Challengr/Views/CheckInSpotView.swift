//
//  CheckInSpotView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 06.03.26.
//


import SwiftUI
import CoreLocation
import MapKit

struct CheckInSpotView: View {
    // MARK: - Input (Eingaben)
    let battleId: Int64
    let socket: GameSocketService
    let targetCoordinate: CLLocationCoordinate2D
    let radius: CLLocationDistance
    let onClose: () -> Void

    // MARK: - State (State)
    @StateObject private var locationHelper = LocationHelper()  // nutzt du ja schon
    @State private var currentLocation: CLLocationCoordinate2D?
    @State private var hasCompleted = false

    // MARK: - Derived values (Abgeleitete Werte)
    private var distanceText: String {
        guard let currentLocation else { return "Position wird bestimmt …" }
        let loc1 = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let loc2 = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
        let d = loc1.distance(from: loc2)  // in Metern
        if d < 1 {
            return "Am Ziel"
        } else if d < 1000 {
            return String(format: "%.0f m bis zum Ziel", d)
        } else {
            return String(format: "%.2f km bis zum Ziel", d / 1000.0)
        }
    }

    // MARK: - Body (UI-Aufbau)

    var body: some View {
        ZStack {
            // Karte mit aktuellem Standort + Ziel
            Map {
                if let currentLocation {
                    Marker("Du", coordinate: currentLocation)
                }
                Marker("Ziel", coordinate: targetCoordinate)
                MapCircle(center: targetCoordinate, radius: radius)
                    .foregroundStyle(Color.green.opacity(0.2))
                    .stroke(Color.green, lineWidth: 2)
            }
            .ignoresSafeArea()

            // Overlay UI
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("CHECK-IN-SPOT")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.black.opacity(0.6))
                        )

                    Text(distanceText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.top, 40)

                Spacer()

                if hasCompleted {
                    Text("ZIEL ERREICHT!")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.green)
                        .padding(.bottom, 4)

                    Text("Die Challenge wird als geschafft markiert.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                Button {
                    onClose()
                } label: {
                    Text("Schließen")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.black.opacity(0.6))
                        )
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
        .onReceive(locationHelper.$userLocation) { loc in
            currentLocation = loc
            checkDistance()
        }
        .onAppear {
            // Startet LocationHelper automatisch, wenn deine Implementierung das macht.
            // Falls nicht, müsstest du hier z.B. locationHelper.request() aufrufen.
        }
    }

    // MARK: - Actions (Aktionen)

    private func checkDistance() {
        guard !hasCompleted, let currentLocation else { return }

        let loc1 = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let loc2 = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
        let d = loc1.distance(from: loc2)

        if d <= radius {
            hasCompleted = true

            // Battle als geschafft melden → wie bei anderen Challenges
            socket.sendUpdateBattleStatus(
                    battleId: battleId,
                    status: "CHECKIN_DONE"
                )
        }
    }
}
