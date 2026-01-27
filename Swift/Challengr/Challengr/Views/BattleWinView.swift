//
//  BattleWinView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 21.01.26.
//
import SwiftUI

struct BattleWinView: View {
    let data: BattleResultData
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Background
            Color.challengrGreen
                .ignoresSafeArea()

            VStack(spacing: 32) {

                // TITLE
                Text("GEWONNEN!")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.challengrWhite)

                // CONGRATS
                Text("GLÜCKWUNSCH, \(data.winnerName.uppercased())!")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.challengrWhite)
                    .multilineTextAlignment(.center)

                // POINTS
                Text("+\(data.winnerPointsDelta) PUNKTE")
                    .font(.system(size: 28, weight: .black))
                    .tracking(1)
                    .foregroundStyle(.challengrWhite)

                Spacer()

                // BACK BUTTON
                Button(action: onClose) {
                    Text("ZURÜCK ZUR KARTE")
                        .font(.system(size: 18, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.challengrBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.challengrWhite)
                        )
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
    }
}
