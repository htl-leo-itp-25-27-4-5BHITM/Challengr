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

struct MapView: View {
    // Startkamera mit Fallback (Wien)
    @State private var position: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .camera(
            MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738), // Wien
                distance: 1000,
                heading: 0,
                pitch: 0
            )
        )
    )

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $position)
                .mapControls {
                    MapCompass()
                }
                .ignoresSafeArea()

            // Apple-offizieller Standortbutton (funktioniert garantiert ab iOS17)
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

#Preview {
    MapView()
}
