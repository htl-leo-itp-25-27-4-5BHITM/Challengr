import SwiftUI

struct ChallengeDialogView: View {
    // Wer wird herausgefordert (für Überschrift + toId)
    let otherPlayerId: Int64
    let otherPlayerName: String

    private let challengesService = ChallengesService()
    // Eigener Spieler (fromId)
    let ownPlayerId: Int64

    // WebSocket zum Backend
    let socket: GameSocketService

    var onClose: () -> Void

    @State private var isLoading = false
    @State private var selectedChallenge: String? = nil
    @State private var selectedChallengeId: Int64? = nil
    @State private var categories: [String] = ["Fitness", "Mutprobe", "Wissen", "Suchen"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Challenge \(otherPlayerName)")
                .font(.title2)
                .fontWeight(.bold)

            if let challenge = selectedChallenge {
                VStack(spacing: 12) {
                    Text("Zufällige Challenge:")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(challenge)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(16)
                        .shadow(radius: 5)
                }
                .padding(.top)
            }

            if isLoading {
                ProgressView("Wird geladen...")
                    .padding()
            } else {
                if selectedChallenge == nil {
                    VStack(spacing: 16) {
                        ForEach(categories, id: \.self) { category in
                            Button {
                                Task {
                                    await loadRandomChallenge(for: category)
                                }
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: icon(for: category))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.white)

                                    Text(category)
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Spacer()
                                }
                                .padding()
                                .background(color(for: category))
                                .cornerRadius(30)
                                .shadow(color: color(for: category).opacity(0.4),
                                        radius: 6, x: 0, y: 4)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }

            Button("Challenge senden") {
                socket.sendCreateBattle(
                    fromId: ownPlayerId,
                    toId: otherPlayerId,
                    challengeId: selectedChallengeId ?? 0
                )
                onClose()
            }
            .disabled(selectedChallenge == nil)


            Button("Schließen") {
                onClose()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(radius: 5)
        }
        .padding()
        .frame(maxWidth: 350)
        .background(.ultraThinMaterial)
        .cornerRadius(30)
        .shadow(radius: 20)
    }

    // MARK: - Challenge laden

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
                selectedChallenge = "Keine Challenge gefunden."
            }
        } catch {
            selectedChallenge = "Fehler beim Laden."
            print("Fehler beim Laden der Kategorie:", error)
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
        default: return .blue
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
