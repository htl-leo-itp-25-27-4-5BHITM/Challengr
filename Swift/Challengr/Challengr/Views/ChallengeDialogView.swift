import SwiftUI

struct ChallengeDialogView: View {
    let playerName: String
    var onClose: () -> Void

    @State private var isLoading = false
    @State private var selectedChallenge: String? = nil
    @State private var categories: [String] = ["Fitness", "Mutprobe", "Wissen", "Suchen"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Challenge \(playerName)")
                .font(.title2)
                .bold()

            if let challenge = selectedChallenge {
                // 📌 Anzeige der gelosten Challenge
                VStack(spacing: 12) {
                    Text("Zufällige Challenge:")
                        .font(.headline)

                    Text(challenge)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(12)
                }
                .padding(.top)
            }

            if isLoading {
                ProgressView("Wird geladen...")
                    .padding()
            } else {
                // 📌 Kategorien anzeigen
                VStack(spacing: 16) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            Task {
                                await loadRandomChallenge(for: category)
                            }
                        } label: {
                            Text(category)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.vertical)
            }

            Button("Schließen") {
                onClose()
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .frame(maxWidth: 320)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 20)
    }

    // 🔥 WICHTIG: Random Challenge für Kategorie laden
    private func loadRandomChallenge(for category: String) async {
        isLoading = true
        selectedChallenge = nil

        do {
            let categoryData = try await loadCategoryChallenges(category: category)

            if let random = categoryData.tasks.randomElement() {
                selectedChallenge = random
            } else {
                selectedChallenge = "Keine Challenge gefunden."
            }

        } catch {
            selectedChallenge = "Fehler beim Laden."
        }

        isLoading = false
    }
}
