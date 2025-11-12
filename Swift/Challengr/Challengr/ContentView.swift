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
            centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738), // Fallback Wien
            distance: 1000,
            heading: 0,
            pitch: 0
        )
    )

    var body: some View {
        NavigationStack {
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

                // LocationButton bleibt unten rechts
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

                // Neuer Navigationsbutton in der Mitte unten
                VStack {
                    Spacer()
                    NavigationLink(destination: ChallengeView()) {
                        Image(systemName: "trophy.fill") // Alternativen: "target", "flame.fill", "flag.checkered"
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
                .navigationTitle("Karte")
                .navigationBarTitleDisplayMode(.inline)


            }
            .navigationTitle("Karte")
            .navigationBarTitleDisplayMode(.inline)
            
        }
    }
}

#Preview {
    ContentView()
}
