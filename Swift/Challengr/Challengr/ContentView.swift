//
//  ContentView.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import SwiftUI

struct ContentView: View {
    let items = [
            CardItem(
                image: Image(systemName: "sportscourt"),
                title: "Fitness",
                subtitle: "Verschiedene sportliche Challanges!"
            ),
            CardItem(
                image: Image(systemName: "flame"),
                title: "Mutprobe",
                subtitle: "Wer traut sich mehr?"

            ),
            CardItem(
                image: Image(systemName: "lightbulb"),
                title: "Wissen",
                subtitle: "Teste dein Wissen!"
            ),
            CardItem(
                image: Image(systemName: "magnifyingglass"),
                title: "Suchen",
                subtitle: "Wer findet etwas zuerst?"
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
        }
    }

    struct CardView: View {

        let item: CardItem

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    item.image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                        .padding(.bottom, 8)

                    Spacer()
                }
               
                Text(item.title)
                    .font(.headline)
                    .fontWeight(.bold)

                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.gray.opacity(0.4), radius: 4, x: 0, y: 2)
        }
    }

    struct CardItem: Identifiable {
        let id = UUID()
        let image: Image
        let title: String
        let subtitle: String
    }


#Preview {
    ContentView()
}
