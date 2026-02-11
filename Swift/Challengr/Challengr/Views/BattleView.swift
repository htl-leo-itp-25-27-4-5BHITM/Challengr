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
    let onSurrender: () -> Void
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            // Background
            Color.challengrWhite
                .ignoresSafeArea()

            VStack(spacing: 32) {

                // CATEGORY
                Text(category.uppercased())
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.challengrBlack)

                // CHALLENGE NAME
                Text(challengeName)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.challengrBlack)

                // VS LINE
                Text("\(playerLeft.uppercased())  VS  \(playerRight.uppercased())")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.challengrBlack.opacity(0.9))

                // PLAYER PANELS
                HStack(spacing: 32) {
                    playerPanel(
                        name: playerLeft,
                        color: .challengrYellow,
                        imageName: "playerBoy"
                    )

                    playerPanel(
                        name: playerRight,
                        color: .chalengrRed,
                        imageName: "playerGirl"
                    )
                }
                .padding(.vertical, 16)

                // QUESTION
                Text("CHALLENGE GESCHAFFT?")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(.challengrBlack)

                // ACTION BUTTONS
                HStack(spacing: 20) {

                    Button(action: onFinished) {
                        Text("GESCHAFFT")
                            .font(.system(size: 16, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.challengrBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.challengrGreen)
                            )
                    }

                    Button(action: onSurrender) {
                        Text("AUFGEBEN ❌")
                            .font(.system(size: 16, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.chalengrRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.chalengrRed, lineWidth: 3)
                            )
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Player Panel
    private func playerPanel(name: String, color: Color, imageName: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.challengrWhite)
                    .frame(width: 110, height: 170)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(color, lineWidth: 3)
                    )

                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 170)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 18)
                    )
            }

            Text(name.uppercased())
                .font(.system(size: 14, weight: .bold))
                .tracking(1)
                .foregroundStyle(color)
        }
    }
}
