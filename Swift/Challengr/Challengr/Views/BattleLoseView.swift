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
            // heller App-Hintergrund
            LinearGradient(
                colors: [
                    Color(.systemGray6),
                    Color(.systemGray5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                // Zentrale Lose-Card
                VStack(spacing: 24) {

                    Text("BATTLE ERGEBNIS")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.challengrRed.opacity(0.9))

                    Text("NIEDERLAGE")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundColor(.challengrRed)

                    Text("KOPF HOCH, \(data.loserName.uppercased())!")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.challengrBlack.opacity(0.9))

                    // Spieler nebeneinander
                    HStack(spacing: 20) {
                        resultPlayerCard(
                            name: data.loserName,
                            avatarName: "playerBoy",
                            pointsDelta: data.loserPointsDelta,
                            isLoser: true
                        )

                        resultPlayerCard(
                            name: data.winnerName,
                            avatarName: "playerGirl",
                            pointsDelta: data.winnerPointsDelta,
                            isLoser: false
                        )
                    }

                    // Punkte-Verlust
                    Text(
                        data.loserPointsDelta == 0
                        ? "0 PUNKTE VERÄNDERT"
                        : "\(data.loserPointsDelta > 0 ? "+" : "")\(data.loserPointsDelta) PUNKTE"
                    )
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(
                        data.loserPointsDelta <= 0
                        ? .challengrRed
                        : .challengrGreen
                    )

                    // Trash-Talk Panel
                    VStack(spacing: 8) {
                        Text("TRASH TALK")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(2)
                            .foregroundColor(.challengrBlack.opacity(0.5))

                        Text(data.trashTalk)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.challengrBlack)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.challengrRed.opacity(0.6), lineWidth: 2)
                    )
                }
                .padding(28)
                .frame(maxWidth: 360)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.white)

                        RoundedRectangle(cornerRadius: 32)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.challengrYellow.opacity(0.4),
                                        Color.challengrRed.opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                )
                .shadow(color: .black.opacity(0.12), radius: 30, x: 0, y: 18)

                // Button zurück zur Karte
                Button(action: onClose) {
                    Text("ZURÜCK ZUR KARTE")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.challengrBlack.opacity(0.85))
                        .frame(maxWidth: 260)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.95))
                        )
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                }
                .padding(.top, 18)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Result Player Card

    private func resultPlayerCard(
        name: String,
        avatarName: String,
        pointsDelta: Int,
        isLoser: Bool
    ) -> some View {
        let color: Color = isLoser ? .challengrRed : .challengrGreen

        return VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .frame(width: 130, height: 190)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)

                RoundedRectangle(cornerRadius: 20)
                    .stroke(color, lineWidth: 3)
                    .frame(width: 118, height: 178)

                Image(avatarName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 118, height: 178)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 20)
                    )

                if isLoser {
                    // kleines X-Badge
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.challengrRed)
                        )
                        .offset(x: -40, y: -70)
                }
            }

            Text(name.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(color)

            Text("\(pointsDelta >= 0 ? "+" : "")\(pointsDelta) PUNKTE")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(color.opacity(0.9))
        }
    }
}
