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

    private var currentPlayerId: String
    private var currentPlayerName: String

    init(playerId: String, playerName: String) {
        self.currentPlayerId = playerId
        self.currentPlayerName = playerName
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func updatePlayerIdentity(playerId: String, playerName: String) {
        currentPlayerId = playerId
        currentPlayerName = playerName
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
