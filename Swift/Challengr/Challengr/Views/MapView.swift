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

struct MapView: View {
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

            LocationButton(.currentLocation) {
                            // Springe zur aktuellen Benutzerposition
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
                    }
                }
        }
    
