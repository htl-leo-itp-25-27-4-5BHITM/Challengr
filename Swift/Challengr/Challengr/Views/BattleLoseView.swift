//
//  BattleLoseView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 21.01.26.
//
import SwiftUI

struct BattleLoseView: View {
    let data: BattleResultData
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Background
            Color.challengrBlack
                .ignoresSafeArea()

            VStack(spacing: 32) {

                // GAME OVER / LOSE HEADER
                Text("NIEDERLAGE")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.chalengrRed)
                    .tracking(2)
                
                // POINTS
                Text(data.loserPointsDelta == 0
                     ? "0 Punkte"
                     : "-\(abs(data.loserPointsDelta)) Punkte")
                    .font(.system(size: 28, weight: .black))
                    .tracking(1)
                    .foregroundStyle(.challengrWhite)

                Spacer()

                // TRASH TALK PANEL
                VStack {
                    Text(data.trashTalk)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.challengrWhite)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.challengrBlack)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.chalengrRed, lineWidth: 3)
                )

                Spacer()

                // CTA BUTTON
                Button(action: onClose) {
                    Text("ZURÜCK ZUR KARTE")
                        .font(.system(size: 18, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.challengrBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.challengrYellow)
                        )
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
    }
}
