//
//  BattleLoseView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 21.01.26.
//
import SwiftUI

struct BattleLoseView: View {
    let data: BattleResultData

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()   // klarer Hintergrund

            VStack(spacing: 24) {
                Text("Niederlage")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)

                VStack(spacing: 8) {
                    // Placeholder avatar
                    Image(systemName: "person.fill.xmark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .foregroundColor(.white)

                    Text(data.loserName.isEmpty ? "Du" : data.loserName)
                        .font(.title2)
                        .foregroundColor(.white)

                    Text("\(data.loserPointsDelta) Punkte")
                        .font(.headline)
                        .foregroundColor(.red)
                }

                Text(data.trashTalk)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()

                Text("Sieger: \(data.winnerName)")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
}


