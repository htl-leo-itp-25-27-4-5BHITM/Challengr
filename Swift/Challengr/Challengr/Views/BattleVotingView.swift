import SwiftUI

struct BattleVotingView: View {
    let playerA: String          // nur Name
    let playerB: String          // nur Name
    let onVote: (String) -> Void

    @State private var selected: String? = nil

    var body: some View {
        ZStack {
            // Cinematischer, heller Hintergrund
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

                // Zentrale "Kinoposter"-Card
                VStack(spacing: 28) {

                    // Kleines Label oben
                    Text("BATTLE VOTE")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.challengrRed.opacity(0.9))

                    // Titel
                    Text("WER HAT\nGEWONNEN?")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(.challengrBlack)

                    // Player-Tiles
                    VStack(spacing: 16) {
                        playerTile(
                            name: playerA,
                            color: .challengrYellow
                        )

                        playerTile(
                            name: playerB,
                            color: .challengrRed
                        )
                    }

                    // Instruction / Feedback
                    if let selected {
                        Text("DU HAST FÜR \(selected.uppercased()) GESTIMMT")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.challengrBlack.opacity(0.8))
                    } else {
                        Text("TIPPE AUF EINEN SPIELER")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.challengrBlack.opacity(0.5))
                    }
                }
                .padding(28)
                .frame(maxWidth: 360)
                .background(
                    ZStack {
                        // leichte Spotlight-Hintergrundfläche
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

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Player Tile

    private func playerTile(
        name: String,
        color: Color
    ) -> some View {
        let isSelected = selected == name
        let isDimmed = selected != nil && !isSelected

        return Button {
            guard selected == nil else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selected = name
            }
            onVote(name)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name.uppercased())
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.challengrBlack)

                    Text("TAP TO VOTE")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.challengrBlack.opacity(0.6))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.challengrBlack.opacity(isSelected ? 0.9 : 0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    // Hauptfläche
                    RoundedRectangle(cornerRadius: 22)
                        .fill(color)

                    // Lichtkante oben
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                        .blendMode(.screen)
                }
            )
            .shadow(
                color: color.opacity(isSelected ? 0.65 : 0.35),
                radius: isSelected ? 22 : 10,
                x: 0,
                y: isSelected ? 12 : 6
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .opacity(isDimmed ? 0.35 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
