//
//  BattleLoseView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 21.01.26.
//
import SwiftUI

struct BattleLoseView: View {
    let data: BattleResultData
    let onClose: () -> Void   // neu

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Niederlage")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)

                Text(data.trashTalk)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()

                Button("Zurück zur Karte") {
                    onClose()          // hier geht's zurück
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



