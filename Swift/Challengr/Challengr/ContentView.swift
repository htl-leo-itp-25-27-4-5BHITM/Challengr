//
//  ContentView.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreLocationUI
import Combine

struct ContentView: View {
    @StateObject private var locationHelper = LocationHelper()
    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
            distance: 1000,
            heading: 0,
            pitch: 0
        )
    )
    @State private var showChallengeView = false // 👈 Für Sheet-Steuerung

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $position)
                .mapControls { MapCompass() }
                .ignoresSafeArea()
                .onReceive(locationHelper.$userLocation) { userLoc in
                    if let userLoc = userLoc {
                        position = .camera(
                            MapCamera(
                                centerCoordinate: userLoc,
                                distance: 1000,
                                heading: 0,
                                pitch: 0
                            )
                        )
                    }
                }

            // 📍 Location Button bleibt unten rechts
            LocationButton(.currentLocation) {
                position = .userLocation(
                    followsHeading: false,
                    fallback: .camera(
                        MapCamera(
                            centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
                            distance: 1000,
                            heading: 0,
                            pitch: 0
                        )
                    )
                )
            }
            .labelStyle(.iconOnly)
            .symbolVariant(.fill)
            .tint(.blue)
            .cornerRadius(12)
            .padding()

            // 🟡 Challenge Button – zentriert unten
            VStack {
                Spacer()
                Button {
                    showChallengeView = true // 👉 Öffnet das Sheet
                } label: {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 100, height: 100)
                        .background(Color.challengrYellow)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
        // 🧭 Sheet-Präsentation (swoosh von unten)
        .sheet(isPresented: $showChallengeView) {
            ChallengeView()
                .presentationDetents([.large]) // optional [.medium, .large]
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    ContentView()
}
