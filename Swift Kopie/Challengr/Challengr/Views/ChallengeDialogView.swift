import SwiftUI

struct ChallengeDialogView: View {

    // MARK: - Input (Eingaben)
    let otherPlayerId: String
    let otherPlayerName: String
    let ownPlayerId: String

    let allChallenges: [ChallengeDTO]      // ⬅️ alle vom MapView vorab geladen
    let socket: GameSocketService
    let onClose: () -> Void

    // MARK: - State (State)
    @State private var isLoading = false
    @State private var selectedChallenge: String? = nil
    @State private var selectedChallengeId: Int64? = nil
    @State private var selectedCategory: String? = nil

    // Kategorien wie in der Webapp / Backend
    private let categories: [String] = ["Fitness", "Mutprobe", "Wissen", "iPhone", "Customer"]

    private var hasAnyLoadedChallenges: Bool {
        !allChallenges.isEmpty
    }

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
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
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

                if !isLoading && !hasAnyLoadedChallenges {
                    Text("Challenges werden noch geladen oder sind gerade nicht verfügbar.")
                        .font(.system(size: 13, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.challengrBlack.opacity(0.75))
                }

                // CATEGORY BUTTONS (nur sichtbar, solange keine Challenge gewählt & nicht loading)
                if selectedChallenge == nil && !isLoading {
                    VStack(spacing: 10) {
                        ForEach(categories, id: \.self) { category in
                            let availableCount = availableChallengeCount(for: category)
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

                                    Text("\(availableCount)")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(color(for: category).opacity(availableCount == 0 ? 0.4 : 1))
                                )
                            }
                            .disabled(availableCount == 0)
                        }
                    }
                }

                // ACTION BUTTONS
                VStack(spacing: 10) {

                    Button {
                        guard let selectedChallengeId else { return }
                        socket.sendCreateBattle(
                            fromId: ownPlayerId,
                            toId: otherPlayerId,
                            challengeId: selectedChallengeId
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
                            .disabled(selectedChallengeId == nil)
                            .opacity(selectedChallengeId == nil ? 0.4 : 1)

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

    // MARK: - Actions (Aktionen)

    private func loadRandomChallenge(for category: String) async {
        isLoading = true
        selectedChallenge = nil
        selectedChallengeId = nil
        selectedCategory = category

        // hier kein Netzwerk – wir benutzen die vom MapView gelieferten Challenges
        let filtered = allChallenges.filter {
            normalizedCategory($0.category) == normalizedCategory(category)
        }

        if let random = filtered.randomElement() {
            selectedChallenge = random.text
            selectedChallengeId = Int64(random.id)
        } else {
            selectedChallenge = "KEINE CHALLENGE IN DIESER KATEGORIE"
        }

        isLoading = false
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

    private func availableChallengeCount(for category: String) -> Int {
        allChallenges.filter {
            normalizedCategory($0.category) == normalizedCategory(category)
        }.count
    }

    private func normalizedCategory(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
