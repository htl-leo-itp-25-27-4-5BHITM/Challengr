import SwiftUI

struct BattleWinView: View {
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

                // Zentrale Win-Card
                VStack(spacing: 24) {

                    // kleines Label
                    Text("BATTLE ERGEBNIS")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.challengrRed.opacity(0.9))

                    // großer WIN-Titel
                    Text("GEWONNEN!")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundColor(.challengrBlack)

                    // Glückwunsch-Zeile
                    Text("GLÜCKWUNSCH, \(data.winnerName.uppercased())!")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.challengrBlack.opacity(0.9))

                    // Winner / Loser Cards nebeneinander
                    HStack(spacing: 20) {
                        resultPlayerCard(
                            name: data.winnerName,
                            avatarName: "playerBoy",
                            pointsDelta: data.winnerPointsDelta,
                            isWinner: true
                        )

                        resultPlayerCard(
                            name: data.loserName,
                            avatarName: "playerGirl",
                            pointsDelta: data.loserPointsDelta,
                            isWinner: false
                        )
                    }

                    // Punkte-Gewinn hervorgehoben
                    Text("+\(data.winnerPointsDelta) PUNKTE")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.challengrGreen)
                        .padding(.top, 4)
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
                                        Color.challengrYellow.opacity(0.6),
                                        Color.challengrGreen.opacity(0.4)
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
        isWinner: Bool
    ) -> some View {
        let color: Color = isWinner ? .challengrGreen : .challengrRed

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

                if isWinner {
                    // kleines Trophy-Badge oben links
                    HStack {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.yellow)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.75))
                            )
                            .offset(x: -40, y: -70)

                        Spacer()
                    }
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
