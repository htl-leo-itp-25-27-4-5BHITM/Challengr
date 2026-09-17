//
//  ChallengeView.swift
//  Challengr
//
//  Created by Julian Richter on 05.11.25.
//

import SwiftUI

struct ChallengeView: View {
    // MARK: - Data (Daten)
    
    let items = [
        CardItem(
            image: Image(systemName: "sportscourt"),
            title: "Fitness",
            subtitle: "Verschiedene sportliche Challenges!",
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
            image: Image(systemName: "iphone.gen3"),
            title: "iPhone",
            subtitle: "Kreative Challenges mit deinem iPhone!",
            color: .challengrBlack
        ),
        CardItem(
            image: Image(systemName: "person.3"),
            title: "Customer",
            subtitle: "Von der Community erstellt.",
            color: .gray
        )
    ]
    // MARK: - Body (UI-Aufbau)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CHALLENGE-KATALOG")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.challengrBlack.opacity(0.5))

                    Text("Wähle eine Kategorie")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.challengrBlack)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

                LazyVStack(spacing: 16) {
                    ForEach(items) { item in
                        NavigationLink(destination: ChallengeDetailView(category: item.title, color: item.color)) {
                            CardView(item: item)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
            .background(.clear)
            .scrollContentBackground(.hidden)
        }
        .background(.clear)
    }
}

// MARK: - Subviews (Unteransichten)

struct CardView: View {

    let item: CardItem

    // MARK: - Body (UI-Aufbau)

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 64, height: 64)

                item.image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title.uppercased())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white)

                Text(item.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(18)
        .background(item.color)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: item.color.opacity(0.4), radius: 10, x: 0, y: 6)
    }
}
// MARK: - Models (Modelle)

    struct CardItem: Identifiable {
        let id = UUID()
        let image: Image
        let title: String
        let subtitle: String
        let color: Color
    }


#Preview {
    ChallengeView()
}
