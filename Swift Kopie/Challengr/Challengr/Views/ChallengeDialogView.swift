import SwiftUI

struct ChallengeDialogView: View {

    // MARK: - Input (Eingaben)
    let otherPlayerId: String
    let otherPlayerName: String
    var otherPlayerRankColor: Color = .gray
    var otherPlayerCharacter: GameCharacter = .opponent
    let ownPlayerId: String

    let allChallenges: [ChallengeDTO]      // ⬅️ alle vom MapView vorab geladen
    let socket: GameSocketService
    let onClose: () -> Void

    // MARK: - State (State)
    @State private var mode: BattleMode? = nil
    @State private var selectedCategory: String = "Fitness"
    @State private var selectedChallengeId: Int64? = nil

    // Kategorien wie in der Webapp / Backend
    private let categories: [String] = ["Fitness", "Mutprobe", "Wissen", "iPhone", "Customer"]

    var body: some View {
        ZStack {
            // DIMMED BACKGROUND
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // CARD
            VStack(spacing: 14) {
                Text("HERAUSFORDERN")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.challengrBlack)

                MapAvatarPin(imageName: otherPlayerCharacter.avatarImageName, ringColor: otherPlayerRankColor, isOwnPlayer: false)

                Text(otherPlayerName.uppercased())
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.challengrBlack)

                if let mode {
                    selectedModeHeader(mode)
                    if mode == .friendly {
                        friendlyPicker
                    } else {
                        Text(mode == .rankedKnowledge
                             ? "4 Fragen, je 15 Sekunden. Richtig gibt Punkte, schneller gibt Bonus."
                             : "Der Server lost eine Handy-Challenge aus – Sprint, Lautstärke, Kompass, Schütteln … Das Handy misst, wer gewinnt.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.challengrBlack.opacity(0.75))
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(BattleMode.allCases.filter(\.isRanked) + [.friendly]) { m in
                            modeButton(m)
                        }
                    }
                }

                // ACTION BUTTONS
                VStack(spacing: 10) {
                    if mode != nil {
                        Button(action: send) {
                            Text("SENDEN")
                                .font(.system(size: 14, weight: .black))
                                .tracking(1)
                                .foregroundStyle(.challengrBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(.challengrGreen))
                        }
                        .disabled(!canSend)
                        .opacity(canSend ? 1 : 0.4)
                    }

                    Button {
                        if mode != nil {
                            withAnimation(.easeInOut(duration: 0.2)) { mode = nil; selectedChallengeId = nil }
                        } else {
                            onClose()
                        }
                    } label: {
                        Text(mode != nil ? "ZURÜCK" : "ABBRECHEN")
                            .font(.system(size: 12, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.chalengrRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 14).stroke(.chalengrRed, lineWidth: 2))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 22).fill(.regularMaterial))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.15), lineWidth: 1))
            .shadow(radius: 20)
            // Spielkarte im Marken-Look: Material und Texte bleiben auch im Dark Mode hell/dunkel.
            .environment(\.colorScheme, .light)
        }
    }

    // MARK: - Modus

    private func modeButton(_ m: BattleMode) -> some View {
        Button {
            SoundManager.shared.play(.tap)
            withAnimation(.easeInOut(duration: 0.2)) { mode = m }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: m.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.title.uppercased())
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(1)
                    Text(m.subtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .opacity(0.85)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
                if m.isRanked {
                    Image(systemName: "trophy.fill").foregroundStyle(.challengrYellow)
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(m.color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(m.title): \(m.subtitle)")
    }

    private func selectedModeHeader(_ m: BattleMode) -> some View {
        Label(m.title.uppercased(), systemImage: m.icon)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(m.color))
    }

    // MARK: - Friendly: Kategorie + Challenge wählen

    private var friendlyPicker: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(categories, id: \.self) { category in
                        let selected = selectedCategory == category
                        Button {
                            selectedCategory = category
                            selectedChallengeId = nil
                        } label: {
                            Label(category, systemImage: icon(for: category))
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(selected ? .white : .challengrBlack)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(selected ? color(for: category) : Color.black.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }

            let list = ChallengePicker.challenges(in: selectedCategory, from: allChallenges)
            if list.isEmpty {
                Text("In dieser Kategorie gibt es noch keine Challenges.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.challengrBlack.opacity(0.7))
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(list) { challenge in
                            let selected = selectedChallengeId == Int64(challenge.id)
                            Button {
                                selectedChallengeId = Int64(challenge.id)
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected ? Color.challengrGreen : .challengrBlack.opacity(0.35))
                                    Text(challenge.text)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.challengrBlack)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                                .padding(9)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(selected ? Color.challengrYellow.opacity(0.5) : Color.black.opacity(0.04)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(challenge.text)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }
                .frame(maxHeight: 210)

                Button {
                    if let random = ChallengePicker.random(in: selectedCategory, from: allChallenges) {
                        selectedChallengeId = Int64(random.id)
                    }
                } label: {
                    Label("Zufällig", systemImage: "dice.fill")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.challengrBlack)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions (Aktionen)

    private var canSend: Bool {
        guard let mode else { return false }
        return mode.isRanked || selectedChallengeId != nil
    }

    private func send() {
        guard let mode, canSend else { return }
        SoundManager.shared.play(.challengeSent)
        socket.sendCreateBattle(
            fromId: ownPlayerId,
            toId: otherPlayerId,
            mode: mode,
            challengeId: mode == .friendly ? selectedChallengeId : nil
        )
        onClose()
    }

    // MARK: - Helpers (Hilfsfunktionen)

    private func color(for category: String) -> Color {
        switch category {
        case "Fitness":  return .challengrYellow
        case "Mutprobe": return .chalengrRed
        case "Wissen":   return .challengrGreen
        case "iPhone":   return .black
        case "Customer": return .gray
        default:         return .challengrYellow
        }
    }

    private func icon(for category: String) -> String {
        switch category {
        case "Fitness":  return "sportscourt"
        case "Mutprobe": return "flame"
        case "Wissen":   return "lightbulb"
        case "iPhone":   return "iphone"
        case "Customer": return "person.2"
        default:         return "questionmark"
        }
    }
}
