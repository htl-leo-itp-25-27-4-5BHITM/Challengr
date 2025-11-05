//
//  MapView.swift
//  Challengr
//
//  Created by Julian Richter on 05.11.25.
//
import SwiftUI
import MapKit
import CoreLocation
import Combine

// Einfacher LocationManager
class UserLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var coordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.coordinate = loc.coordinate
        }
    }
}

struct MapView: View {
    @StateObject private var locationManager = UserLocationManager()
    @State private var position: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .camera(
            MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738), // Wien
                distance: 500,
                heading: 0,
                pitch: 0
            )
        )
    )

    var body: some View {
        Map(position: $position)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea()
            .onReceive(locationManager.$coordinate) { coordinate in
                if let coordinate = coordinate {
                    // Sobald der echte Standort da ist, springe dahin
                    position = .camera(
                        MapCamera(
                            centerCoordinate: coordinate,
                            distance: 500,
                            heading: 0,
                            pitch: 0
                        )
                    )
                }
            }
    }
}

#Preview {
    MapView()
}
