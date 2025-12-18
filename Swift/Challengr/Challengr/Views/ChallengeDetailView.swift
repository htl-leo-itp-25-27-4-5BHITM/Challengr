//
//  ChallengeDetailView.swift
//  Challengr
//
//  Created by Julian Richter on 22.10.25.
//

import SwiftUI

struct ChallengeDetailView: View {
    let category: String
    let color: Color

    @State private var description: String = ""
    @State private var tasks: [String] = []
    @State private var isLoading = true

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

                    Text(description)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.bottom, 10)

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

    func loadCategory() async {
        do {
            let challenges = try await loadCategoryChallenges(category: category)

            // Beschreibung aus erster Challenge
            description = challenges.first?.challengeCategory.description ?? ""

            // Alle Texte als Aufgabenliste
            tasks = challenges.map { $0.text }
        } catch {
            print("Fehler beim Laden der Kategorie:", error)
        }
        isLoading = false
    }


}
