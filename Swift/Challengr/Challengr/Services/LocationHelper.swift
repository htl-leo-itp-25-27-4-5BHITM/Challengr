//
//  LocationHelper.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 11.11.25.
//

import Foundation
import CoreLocation
import Combine

class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self                   // Wichtig!
        manager.requestWhenInUseAuthorization()   // Standortberechtigung
        manager.startUpdatingLocation()           // Standortupdates starten
    }

    // Diese Funktion wird jedes Mal aufgerufen, wenn sich die Position ändert
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            DispatchQueue.main.async {
                self.userLocation = location.coordinate

                // Spieler in der Datenbank erstellen oder Position updaten
                Task {
                                // Sicherstellen, dass ein Spieler existiert
                                try? await PlayerService.shared.updateOrCreatePlayer(
                                    name: "Julian",
                                    location: location.coordinate
                                )
                            }
            }
        }
    }

    // Optional: Fehlerhandling, wenn Standort nicht verfügbar
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed: \(error.localizedDescription)")
    }
}
