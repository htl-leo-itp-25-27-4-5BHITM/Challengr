import SwiftUI

struct ChallengeDialogView: View {

    // MARK: - Input
    let otherPlayerId: Int64
    let otherPlayerName: String
    let ownPlayerId: Int64

    let socket: GameSocketService
    let onClose: () -> Void

    private let challengesService = ChallengesService()

    // MARK: - State
    @State private var isLoading = false
    @State private var selectedChallenge: String? = nil
    @State private var selectedChallengeId: Int64? = nil

    private let categories: [String] = ["Fitness", "Mutprobe", "Wissen", "Suchen"]

    var body: some View {
        ZStack {

            // DIMMED BACKGROUND
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // CARD
            VStack(spacing: 18) {

                // HEADER
                Text("CHALLENGE")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.challengrBlack)

                Text(otherPlayerName.uppercased())
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.challengrBlack)

                // SELECTED CHALLENGE
                if let challenge = selectedChallenge {
                    VStack(spacing: 8) {

                        Text("ZUFÄLLIGE CHALLENGE")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.2)
                            .foregroundStyle(.challengrBlack)

                        Text(challenge)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.challengrBlack)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.challengrYellow)
                            )
                    }
                }

                // LOADING
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                }

                // CATEGORY BUTTONS
                if selectedChallenge == nil && !isLoading {
                    VStack(spacing: 10) {
                        ForEach(categories, id: \.self) { category in
                            Button {
                                Task {
                                    await loadRandomChallenge(for: category)
                                }
                            } label: {
                                HStack(spacing: 12) {

                                    Image(systemName: icon(for: category))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)

                                    Text(category.uppercased())
                                        .font(.system(size: 14, weight: .black))
                                        .tracking(1)
                                        .foregroundStyle(.white)

                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(color(for: category))
                                )
                            }
                        }
                    }
                }

                // ACTION BUTTONS
                VStack(spacing: 10) {

                    Button {
                        socket.sendCreateBattle(
                            fromId: ownPlayerId,
                            toId: otherPlayerId,
                            challengeId: selectedChallengeId ?? 0
                        )
                        onClose()
                    } label: {
                        Text("SENDEN")
                            .font(.system(size: 14, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.challengrBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.challengrGreen)
                            )
                    }
                    .disabled(selectedChallenge == nil)
                    .opacity(selectedChallenge == nil ? 0.4 : 1)

                    Button(action: onClose) {
                        Text("ABBRECHEN")
                            .font(.system(size: 12, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.chalengrRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.chalengrRed, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 300)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(radius: 20)
        }
    }

    // MARK: - Logic
    private func loadRandomChallenge(for category: String) async {
        isLoading = true
        selectedChallenge = nil
        selectedChallengeId = nil

        do {
            let challenges = try await challengesService.loadCategoryChallenges(category: category)
            if let random = challenges.randomElement() {
                selectedChallenge = random.text
                selectedChallengeId = Int64(random.id)
            } else {
                selectedChallenge = "KEINE CHALLENGE"
            }
        } catch {
            selectedChallenge = "FEHLER"
            print(error)
        }

        isLoading = false
    }

    // MARK: - Design Helper
    private func color(for category: String) -> Color {
        switch category {
        case "Fitness": return .challengrYellow
        case "Mutprobe": return .chalengrRed
        case "Wissen": return .challengrGreen
        case "Suchen": return .challengrBlack
        default: return .challengrWhite
        }
    }

    private func icon(for category: String) -> String {
        switch category {
        case "Fitness": return "sportscourt"
        case "Mutprobe": return "flame"
        case "Wissen": return "lightbulb"
        case "Suchen": return "magnifyingglass"
        default: return "questionmark"
        }
    }
}
