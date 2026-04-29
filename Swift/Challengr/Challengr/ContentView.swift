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
        Group {
            if auth.isAuthenticated {
                if let playerId = auth.playerId {
                    MapView(
                        ownPlayerId: playerId,
                        ownPlayerName: auth.playerName,
                        auth: auth
                    )
                } else {
                    VStack(spacing: 12) {
                        if let error = auth.errorMessage {
                            Text("Fehler beim Laden:")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.secondary)
                        } else {
                            ProgressView("Lade Profil …")
                        }
                    }
                    .padding()
                }
            } else {
                LoginView(auth: auth)
            }
        }
    }
}

#Preview {
    ContentView()
}
