//
//  MapView.swift
//  Challengr
//
//  Created by Julian Richter on 05.11.25.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreLocationUI
import Combine

struct PlayerAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct MapView: View {
    @StateObject private var locationHelper = LocationHelper()

    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
            distance: 1000,
            heading: 0,
            pitch: 0
        )
    )

    // MARK: - Marker (Spielerpositionen)
    @State private var annotations: [PlayerAnnotation] = [
        PlayerAnnotation(
            coordinate: CLLocationCoordinate2D(latitude: 48.26835, longitude: 14.25235),
            title: "Challengr"
        )
    ]

    @State private var showChallengeView = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            // MARK: - SwiftUI Map mit Marker-Unterstützung
            Map(position: $position) {
                ForEach(annotations) { annotation in
                    Marker(annotation.title, coordinate: annotation.coordinate).tint(.chalengrRed)
                }
            }
            .mapStyle(
                .standard(
                    elevation: .realistic,
                    pointsOfInterest: .excludingAll,
                    showsTraffic: false
                )
            )
            .tint(.challengrGreen)
            .accentColor(.challengrYellow)
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

            // MARK: - Location Button
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

            // MARK: - Challenge Button
            VStack {
                Spacer()
                Button {
                    showChallengeView = true
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
        // MARK: - Challenge Sheet
        .sheet(isPresented: $showChallengeView) {
            ChallengeView()
                .presentationDetents([ .medium ])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
    }
}
