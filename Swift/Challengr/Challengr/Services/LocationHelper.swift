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

    @Published var userLocation: CLLocationCoordinate2D?

    private let manager = CLLocationManager()
    private let playerService = PlayerLocationService()

    // Später z.B. aus Login laden
    let currentPlayerId: Int64 = 1
    let currentPlayerName: String = "EigenerSpieler"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let coord = loc.coordinate
        DispatchQueue.main.async {
            self.userLocation = coord
        }

        Task {
            try? await playerService.updatePlayer(
                id: currentPlayerId,
                name: currentPlayerName,
                latitude: coord.latitude,
                longitude: coord.longitude
            )
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}
