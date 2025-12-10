//
//  ChallengeDialogView.swift
//  Challengr
//
//  Created by Dominik Binder on 10.12.25.
//

import SwiftUI

struct ChallengeDialogView: View {
    let playerName: String
    var onClose: () -> Void  // Callback zum Schließen

    var body: some View {
        VStack(spacing: 20) {
            Text("Challenge \(playerName)")
                .font(.title2)
                .bold()

            Text("Hier kommt später der Dialog zum Herausfordern hin.")
                .multilineTextAlignment(.center)

            Button("Schließen") {
                onClose()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .frame(maxWidth: 300)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

