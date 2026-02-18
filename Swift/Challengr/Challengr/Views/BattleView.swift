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
            // Hintergrund wie VotingView
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

                // Zentrale Battle-Card
                VStack(spacing: 24) {

                    // Kategorie
                    Text(category.uppercased())
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(1.8)
                        .foregroundColor(.challengrRed.opacity(0.9))

                    // Challenge-Titel
                    Text(challengeName)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.challengrBlack)

                    // Spieler-Namen
                    Text("\(playerLeft.uppercased())  VS  \(playerRight.uppercased())")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.challengrBlack.opacity(0.85))

                    // FIGHT-Szene: Charaktere gegenüber + VS
                    // FIGHT-Szene: Charaktere gegenüber + VS
                    ZStack {
                        // Hintergrund-Glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.challengrYellow.opacity(0.35),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 150
                                )
                            )
                            .frame(width: 200, height: 200)
                            .offset(y: 10)

                        // Nur die beiden Panels in einem HStack
                        HStack(spacing: 60) {
                            playerPanel(
                                name: playerLeft,
                                color: .challengrYellow,
                                imageName: "playerBoy",
                                flip: false
                            )
                            .rotationEffect(.degrees(-6))

                            playerPanel(
                                name: playerRight,
                                color: .challengrRed,
                                imageName: "playerGirl",
                                flip: true
                            )
                            .rotationEffect(.degrees(6))
                        }
                        .padding(.horizontal, 8)

                        // VS als eigene Ebene ganz vorne
                        Text("VS")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .tracking(4)                         // sorgt dafür, dass V und S nebeneinander stehen
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.challengrRed,
                                                Color.challengrYellow
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                    }
                    .padding(.top, 8)


                    // Frage
                    Text("CHALLENGE GESCHAFFT?")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(.challengrBlack)

                    // Action-Buttons
                    HStack(spacing: 16) {
                        // Geschafft
                        GamePrimaryButton(title: "Geschafft", color: .challengrGreen) {
                            onFinished()
                        }

                        // Aufgeben
                        Button(action: onSurrender) {
                            HStack {
                                Text("AUFGEBEN")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .tracking(1)
                                Text("✖")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                            }
                            .foregroundColor(.challengrRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.challengrRed, lineWidth: 2)
                            )
                        }
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                    }
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
                                        Color.challengrYellow.opacity(0.5),
                                        Color.challengrRed.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                )
                .shadow(color: .black.opacity(0.12), radius: 30, x: 0, y: 18)

                // Schließen-Button
                Button(action: onClose) {
                    Text("SCHLIESSEN")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.challengrBlack.opacity(0.8))
                        .frame(maxWidth: 260)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.9))
                        )
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                }
                .padding(.top, 18)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Player Panel

    private func playerPanel(
        name: String,
        color: Color,
        imageName: String,
        flip: Bool
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.white)
                    .frame(width: 120, height: 180)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)

                RoundedRectangle(cornerRadius: 22)
                    .stroke(color, lineWidth: 3)
                    .frame(width: 110, height: 170)

                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 170)
                    .scaleEffect(x: flip ? -1 : 1, y: 1)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 22)
                    )
            }

            Text(name.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(color)
        }
    }
}
