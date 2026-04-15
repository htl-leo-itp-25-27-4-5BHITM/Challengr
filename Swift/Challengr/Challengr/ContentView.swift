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
    @StateObject private var auth = KeycloakAuthService()

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        MapView(
            ownPlayerId: 1,
            ownPlayerName: "Preview",
            auth: auth
        )
    }
}

#Preview {
    ContentView()
}
