import SwiftUI

/// Menü → Üben: Quiz-Show oder Real-Life gegen den Trainings-Dummy – auch wenn niemand in der Nähe ist.
struct PracticeDialogView: View {

    // MARK: - Input (Eingaben)
    let ownPlayerId: String
    let socket: GameSocketService
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 14) {
                Text("ÜBEN")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.challengrYellow)

                MapAvatarPin(imageName: PracticeBot.character.avatarImageName, ringColor: .gray, isOwnPlayer: false)

                Text(PracticeBot.name.uppercased())
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Niemand in der Nähe? Spiel gegen den Dummy. Es geht um nichts – keine Trophäen, keine Sticker.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(GameStyle.secondaryText)

                VStack(spacing: 10) {
                    practiceButton(.rankedKnowledge)
                    practiceButton(.rankedRealLife)
                }

                Button(action: onClose) {
                    Text("ABBRECHEN")
                        .font(.system(size: 12, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.25), lineWidth: 1.5))
                }
            }
            .padding(18)
            .frame(maxWidth: 330)
            .gameOverlayCard()
        }
    }

    private func practiceButton(_ mode: BattleMode) -> some View {
        Button {
            SoundManager.shared.play(.challengeSent)
            socket.sendCreateBattle(fromId: ownPlayerId, toId: PracticeBot.id, mode: mode)
            onClose()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.shortTitle.uppercased())
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(1)
                    Text(mode.subtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .opacity(0.85)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(mode.color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Üben: \(mode.shortTitle)")
    }
}
