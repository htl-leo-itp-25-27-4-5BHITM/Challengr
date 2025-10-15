//
//  ContentView.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import SwiftUI

struct ContentView: View {
    
    @State private var challenges: ChallengeData = [:]
    
    let items = [
            CardItem(
                image: Image(systemName: "sportscourt"),
                title: "Fitness",
                subtitle: "Verschiedene sportliche Challanges!",
                color: .challengrYellow
            ),
            CardItem(
                image: Image(systemName: "flame"),
                title: "Mutprobe",
                subtitle: "Wer traut sich mehr?",
                color: .chalengrRed

            ),
            CardItem(
                image: Image(systemName: "lightbulb"),
                title: "Wissen",
                subtitle: "Teste dein Wissen!",
                color: .challengrGreen
            ),
            CardItem(
                image: Image(systemName: "magnifyingglass"),
                title: "Suchen",
                subtitle: "Wer findet etwas zuerst?",
                color: .challengrBlack
            )
        ]

        var body: some View {

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(items) { item in
                        CardView(item: item)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
            .background(Color(UIColor.systemGray6))
            .edgesIgnoringSafeArea(.bottom)
            
            List {
                    ForEach(challenges.keys.sorted(), id: \.self) { category in
                        Section(header: Text(category)) {
                            ForEach(challenges[category]!, id: \.self) { item in
                                Text(item)
                            }
                        }
                    }
                }
                .task {
                    do {
                        challenges = try await loadChallenges()
                    } catch {
                        print("Fehler beim Laden:", error)
                    }
                }

        }
    }

struct CardView: View {

    let item: CardItem

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            item.image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(item.color)
        .cornerRadius(40)
        .shadow(color: item.color.opacity(0.4), radius: 6, x: 0, y: 4)
    }
}


    struct CardItem: Identifiable {
        let id = UUID()
        let image: Image
        let title: String
        let subtitle: String
        let color: Color
    }


#Preview {
    ContentView()
}
