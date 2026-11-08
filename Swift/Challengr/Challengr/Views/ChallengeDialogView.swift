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
    /// Nach dem Absenden (z.B. Freundes-Menü schließen, damit man die Karte sieht)
    var onSent: () -> Void = {}
    let onClose: () -> Void

    // MARK: - State (State)
    @State private var mode: BattleMode? = nil
    @State private var selectedCategory: String = ChallengeDialogView.quizCategory
    @State private var selectedChallengeId: Int64? = nil

    /// Eigene Kachel im Friendly: Quiz-Show (4 Fragen) statt einer gewählten Challenge.
    static let quizCategory = "Quiz-Show"
    /// Fitness (selbst gezählt) und die einzelne Wissensfrage gibt es im Friendly nicht mehr.
    private let categories: [String] = [ChallengeDialogView.quizCategory, "iPhone", "Mutprobe", "Customer"]
    private var quizPicked: Bool { selectedCategory == ChallengeDialogView.quizCategory }

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
                    .foregroundStyle(.challengrYellow)

                MapAvatarPin(imageName: otherPlayerCharacter.avatarImageName, ringColor: otherPlayerRankColor, isOwnPlayer: false)

                Text(otherPlayerName.uppercased())
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

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
                            .foregroundStyle(GameStyle.secondaryText)
                    }
                } else {
                    VStack(spacing: 10) {
                        // Eine Liga, zwei Spielarten – beide zählen auf dieselben Trophäen
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill").foregroundStyle(.challengrYellow)
                            Text("LIGA · UM TROPHÄEN")
                                .tracking(1)
                        }
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                        HStack(spacing: 10) {
                            leagueButton(.rankedKnowledge)
                            leagueButton(.rankedRealLife)
                        }

                        Text("ODER")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.top, 2)

                        modeButton(.friendly)
                    }
                }

                // ACTION BUTTONS
                VStack(spacing: 10) {
                    if mode != nil {
                        Button(action: send) {
                            Text("SENDEN")
                                .font(.system(size: 14, weight: .black))
                                .tracking(1)
                                .foregroundStyle(Color.challengrDark)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(.challengrYellow))
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
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.25), lineWidth: 1.5))
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 330)
            // Spielkarte im Marken-Look (dunkel wie Battle, Profil, Sticker)
            .gameOverlayCard()
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

    /// Liga-Spielart als Kachel (Quiz-Show / Real-Life-Challenge).
    private func leagueButton(_ m: BattleMode) -> some View {
        Button {
            SoundManager.shared.play(.tap)
            withAnimation(.easeInOut(duration: 0.2)) { mode = m }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: m.icon)
                    .font(.system(size: 24, weight: .bold))
                Text(m.shortTitle.uppercased())
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(0.6)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 86)
            .padding(.horizontal, 6)
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
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(selected ? color(for: category) : Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }

            let list = ChallengePicker.challenges(in: selectedCategory, from: allChallenges)
            if quizPicked {
                Text("4 Wissensfragen, je 15 Sekunden. Richtig gibt Punkte, schneller gibt Bonus. Es geht um nichts.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(GameStyle.secondaryText)
                    .padding(.vertical, 6)
            } else if list.isEmpty {
                Text("In dieser Kategorie gibt es noch keine Challenges.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GameStyle.secondaryText)
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
                                        .foregroundStyle(selected ? Color.challengrDark : .white.opacity(0.35))
                                    Text(challenge.text)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(selected ? Color.challengrDark : .white)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                                .padding(9)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(selected ? Color.challengrYellow : Color.white.opacity(0.06)))
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
                        .foregroundStyle(.challengrYellow)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions (Aktionen)

    private var canSend: Bool {
        guard let mode else { return false }
        return mode.isRanked || quizPicked || selectedChallengeId != nil
    }

    private func send() {
        guard let mode, canSend else { return }
        SoundManager.shared.play(.challengeSent)
        socket.sendCreateBattle(
            fromId: ownPlayerId,
            toId: otherPlayerId,
            mode: mode == .friendly && quizPicked ? .friendlyQuiz : mode,
            challengeId: mode == .friendly && !quizPicked ? selectedChallengeId : nil
        )
        onClose()
        onSent()
    }

    // MARK: - Helpers (Hilfsfunktionen)

    private func color(for category: String) -> Color {
        switch category {
        case "Fitness":  return .challengrYellow
        case "Mutprobe": return .chalengrRed
        case "Wissen", ChallengeDialogView.quizCategory: return .purple
        case "iPhone":   return Color(white: 0.35)
        case "Customer": return .gray
        default:         return .challengrYellow
        }
    }

    private func icon(for category: String) -> String {
        switch category {
        case "Fitness":  return "sportscourt"
        case "Mutprobe": return "flame"
        case "Wissen":   return "lightbulb"
        case ChallengeDialogView.quizCategory: return "brain.head.profile"
        case "iPhone":   return "iphone"
        case "Customer": return "person.2"
        default:         return "questionmark"
        }
    }
}
