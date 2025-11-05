//
//  MapView.swift
//  Challengr
//
//  Created by Julian Richter on 05.11.25.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0), // Startwert
        span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5) // Zoom-Level 5
    )
    
    @State private var locationManager = CLLocationManager()
    
    var body: some View {
        Map(coordinateRegion: $region, showsUserLocation: true)
            .onAppear {
                locationManager.requestWhenInUseAuthorization()
                locationManager.startUpdatingLocation()
                
                if let location = locationManager.location?.coordinate {
                    region.center = location
                    region.span = MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
                }
            }
            .mapControls {
                MapUserLocationButton() // Zurück zum eigenen Standort
                MapCompass()
            }
            .ignoresSafeArea()
    }
}

#Preview {
    MapView()
}
