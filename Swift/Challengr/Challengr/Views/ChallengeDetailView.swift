//
//  ChallengeDetailView.swift
//  Challengr
//
//  Created by Julian Richter on 22.10.25.
//

import SwiftUI

struct ChallengeDetailView: View {
    // MARK: - Input (Eingaben)
    let category: String
    let color: Color

    // MARK: - State (State)
    @State private var description: String = ""
    @State private var tasks: [String] = []
    @State private var isLoading = true

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        ZStack {
            color.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView("Lade \(category)...")
                        .tint(.white)
                        .foregroundColor(.white)
                } else {
                    Text(category)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if !description.isEmpty {
                        Text(description)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.bottom, 10)
                    }

                    List(tasks, id: \.self) { task in
                        Text(task)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCategory()
        }
    }

    // MARK: - Actions (Aktionen)

    func loadCategory() async {
        do {
            let challenges = try await ChallengesService()
                .loadCategoryChallenges(category: category)

            // Beschreibung: aus der ChallengeCategory kommt nichts mehr,
            // daher einfach einen festen Text pro Kategorie wählen:
            switch category {
            case "Fitness":
                description = "Beweise deine Kraft und bleib in Bewegung!"
            case "Mutprobe":
                description = "Zeig Mut – verlasse deine Komfortzone!"
            case "Wissen":
                description = "Teste dein Wissen über die Welt!"
            case "iPhone":
                description = "Kreative Challenges mit deinem iPhone!"
            case "Customer":
                description = "Von der Community erstellte Challenges."
            default:
                description = ""
            }

            // Texte der Challenges
            tasks = challenges.map { $0.text }
        } catch {
            print("Fehler beim Laden der Kategorie:", error)
        }
        isLoading = false
    }
}
