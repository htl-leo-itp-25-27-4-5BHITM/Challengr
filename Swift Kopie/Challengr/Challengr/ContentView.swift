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
    @StateObject private var friendsInbox = FriendsInboxStore()
    @StateObject private var inviteFlow = FriendInviteFlow()

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
                    .environmentObject(friendsInbox)
                    .task {
                        friendsInbox.startPolling(playerId: playerId)
                    }
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
