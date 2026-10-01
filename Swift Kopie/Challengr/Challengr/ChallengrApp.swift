//
//  ChallengrApp.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import SwiftUI


@main
struct ChallengrApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Hintergrundmusik nur, solange die App im Vordergrund ist
            SoundManager.shared.setAppActive(phase == .active)
        }
    }
}
