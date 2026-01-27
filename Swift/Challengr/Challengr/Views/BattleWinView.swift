//
//  BattleWinView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 21.01.26.
//
import SwiftUI

struct BattleWinView: View {
    let data: BattleResultData

    var body: some View {
        VStack(spacing: 24) {
            Text("Sieg!")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                Image(data.winnerAvatar)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)

                Text(data.winnerName)
                    .font(.title2)

                Text("+\(data.winnerPointsDelta) Punkte")
                    .foregroundColor(.green)
                    .font(.headline)
            }

            Spacer()

            Text("Sieger: \(data.winnerName)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
