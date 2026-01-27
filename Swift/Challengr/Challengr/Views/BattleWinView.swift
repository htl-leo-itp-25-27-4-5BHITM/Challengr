//
//  BattleWinView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 21.01.26.
//
import SwiftUI

struct BattleWinView: View {
    let data: BattleResultData
    let onClose: () -> Void   // wie bei Lose

    var body: some View {
        ZStack {
            Color.green.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Gewonnen!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Glückwunsch, \(data.winnerName)!")
                    .foregroundColor(.white)

                Text("+\(data.winnerPointsDelta) Punkte")
                    .font(.title2)
                    .foregroundColor(.white)

                Spacer()

                Button("Zurück zur Karte") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.black)
                .padding(.bottom, 40)
            }
            .padding()
        }
    }
}

