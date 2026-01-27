//
//  BattleView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 19.01.26.
//


import SwiftUI

struct BattleResultData {
    let winnerName: String
    let winnerAvatar: String   // später: Bildname
    let winnerPointsDelta: Int

    let loserName: String
    let loserAvatar: String
    let loserPointsDelta: Int

    let trashTalk: String      // nur im Lose-Screen angezeigt
}


struct BattleView: View {
    let challengeName: String
    let category: String
    let playerLeft: String
    let playerRight: String
    let onClose: () -> Void
    let onSurrender: () -> Void // zum Schließen

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, .gray],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(category.uppercased())
                    .font(.caption)
                    .foregroundColor(.yellow)

                Text(challengeName)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("\(playerLeft)  VS  \(playerRight)")
                    .font(.headline)
                    .padding(.top, 8)

                // Platzhalter für spätere Figuren
                HStack(spacing: 40) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue)
                        .frame(width: 100, height: 160)

                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red)
                        .frame(width: 100, height: 160)
                }
                .padding(.vertical, 16)

                Text("Challenge geschafft?")
                    .font(.subheadline)

                HStack(spacing: 24) {
                    Button("Geschafft ✅") {
                        // TODO: später Ergebnis ans Backend schicken
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Aufgeben ❌") {
                        onSurrender()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Spacer()
            }
            .foregroundColor(.white)
            .padding()
        }
    }
}
