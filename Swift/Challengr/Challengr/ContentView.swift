//
//  ContentView.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ChallengeView()
                .tabItem {
                    Label("Challenge", systemImage: "star")
                }
            MapView()
                .tabItem {
                    Label("Map", systemImage: "mappin.and.ellipse")
                }
        }
        
    }
}

#Preview {
    ContentView()
}
