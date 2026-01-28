//
//  TrophyRoadView.swift
//  Challengr
//
//  Created by Julian Richter on 28.01.26.
//

import SwiftUI

// MARK: - Model
struct TrophyRank: Identifiable {
    let id = UUID()
    let name: String
    let range: ClosedRange<Int>
    let color: Color
}

// MARK: - Data
let trophyRanks: [TrophyRank] = [
    .init(name: "Quitter", range: 0...99, color: .gray),
    .init(name: "Punchbag", range: 100...199, color: .red),
    .init(name: "Scrapper", range: 200...349, color: .green),
    .init(name: "Contender", range: 350...599, color: .yellow),
    .init(name: "Tryhard", range: 600...949, color: .orange),
    .init(name: "Brawler", range: 950...1399, color: .red),
    .init(name: "Dueler", range: 1400...1999, color: .purple),
    .init(name: "Challengr", range: 2000...2800, color: .yellow)
]

// MARK: - View
struct TrophyRoadView: View {
    @State private var playerPoints: Int = 210

    private var currentRank: TrophyRank {
        trophyRanks.first { $0.range.contains(playerPoints) } ?? trophyRanks[0]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("TROPHY ROAD")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .gray.opacity(0.4), radius: 6, x: 2, y: 2)
                        .padding(.top, 20)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(trophyRanks.indices.reversed(), id: \.self) { index in
                                let rank = trophyRanks[index]
                                rankBox(for: rank)

                                if index > 0 {
                                    let lowerRank = trophyRanks[index - 1]
                                    etappenBlock(from: lowerRank, to: rank)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                
                VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            NavigationLink(destination: ChallengeView()) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.blue)
                                    .padding()
                                    .background(Circle().fill(Color.white))
                                    .shadow(radius: 6)
                            }
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                        }
                    }
            }
        }
    }

    // MARK: - Rank Box
    private func rankBox(for rank: TrophyRank) -> some View {
        let isCurrentRank = rank.id == currentRank.id

        return VStack(alignment: .leading, spacing: 8) {
            Text(rank.name.uppercased())
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
                .shadow(radius: 2)

            Text("\(rank.range.lowerBound) – \(rank.range.upperBound)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.85))

            if isCurrentRank {
                Text("AKTUELL")
                    .font(.system(size: 12, weight: .black))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white))
                    .foregroundColor(rank.color)
                    .shadow(radius: 2)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [rank.color.opacity(0.95), rank.color.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(28)
        .shadow(color: rank.color.opacity(0.3), radius: 10, y: 6)
        .padding(.vertical, 12)
    }

    // MARK: - Etappen Block (korrekter Fortschritt)
    private func etappenBlock(from lowerRank: TrophyRank, to upperRank: TrophyRank) -> some View {
        let steps = 8
        let stepHeight: CGFloat = 36
        let totalHeight = CGFloat(steps - 1) * stepHeight

        let isCurrentRank = lowerRank.id == currentRank.id

        // 🔢 Fortschritt (0.0 – 1.0)
        let progress: CGFloat = {
            guard isCurrentRank else { return 0 }

            let lower = lowerRank.range.lowerBound
            let upper = lowerRank.range.upperBound

            let clampedPoints = Swift.max(
                Swift.min(playerPoints, upper),
                lower
            )

            return CGFloat(clampedPoints - lower) / CGFloat(upper - lower)
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.3))
                .frame(width: 10)
                .frame(height: CGFloat(steps) * stepHeight)

            VStack(spacing: stepHeight) {
                ForEach(0..<steps, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 16, height: 16)
                        .shadow(radius: 1)
                }
            }

            // 🎯 Aktuelle Position – proportional zu den Trophäen
            if isCurrentRank {
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle().stroke(upperRank.color, lineWidth: 3)
                    )
                    .shadow(color: upperRank.color.opacity(0.8), radius: 12)
                    .offset(y: totalHeight / 2 - (progress * totalHeight))
                    .animation(.spring(), value: playerPoints)
            }
        }
        .padding(.vertical, 8)
    }
}
