//
//  ChallengrApp.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import SwiftUI


@main
struct ChallengrApp: App {
    @StateObject private var auth = KeycloakAuthService()

    init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--use-local-backend") {
            UserDefaults.standard.set(true, forKey: BackendConfig.useLocalBackendKey)
        }
        if args.contains("--use-cloud-backend") {
            UserDefaults.standard.set(false, forKey: BackendConfig.useLocalBackendKey)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
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
                            ProgressView()
                            Text("Profil wird geladen…")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                    }
                } else {
                    LoginView(auth: auth)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: auth.isAuthenticated)
        }
    }
}
