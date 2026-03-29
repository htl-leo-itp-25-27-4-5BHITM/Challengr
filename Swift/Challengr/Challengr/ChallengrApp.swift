//
//  ChallengrApp.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import SwiftUI


@main
struct ChallengrApp: App {
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
            ContentView()
        }
    }
}
