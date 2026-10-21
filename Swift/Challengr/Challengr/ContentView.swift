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
    @StateObject private var inviteFlow = FriendInviteFlow()
    @State private var showOnboarding = OnboardingView.shouldShow

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
                    .fullScreenCover(isPresented: $showOnboarding) {
                        OnboardingView {
                            showOnboarding = false
                        }
                    }
                } else {
                    LoadingScreen(error: auth.errorMessage)
                }
            } else if auth.isRestoring {
                // Gespeicherter Login: kurz der Lade-Screen, nicht die Login-Seite
                LoadingScreen()
            } else {
                LoginView(auth: auth)
            }
        }
        .task(id: auth.playerId) {
            await inviteFlow.resumePendingInvite(ownPlayerId: auth.playerId)
        }
        .onOpenURL { url in
            Task {
                await inviteFlow.receive(url: url, ownPlayerId: auth.playerId)
            }
        }
        .alert("Freundesanfrage", isPresented: Binding(
            get: { inviteFlow.alertMessage != nil },
            set: { if !$0 { inviteFlow.clearAlert() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(inviteFlow.alertMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
}
