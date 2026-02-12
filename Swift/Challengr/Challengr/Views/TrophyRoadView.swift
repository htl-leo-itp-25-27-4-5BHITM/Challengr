//
//  TrophyRoadView.swift
//  Challengr
//
//  Created by Julian Richter on 28.01.26.
//

import SwiftUI

// MARK: - Model

struct TrophyRank: Identifiable, Codable {
    let id = UUID()
    let name: String
    let min: Int
    let max: Int
    let color: String

    var range: ClosedRange<Int> { min...max }

    var uiColor: Color {
        switch color.lowercased() {
        case "gray":   return .gray
        case "red":    return .red
        case "green":  return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        default:       return .blue
        }
    }
}

// MARK: - Service

final class RankService {
    private let baseURL = URL(string: "http://localhost:8080")!   // ggf. anpassen

    func loadRanks() async throws -> [TrophyRank] {
        let url = baseURL.appendingPathComponent("/api/ranks")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([TrophyRank].self, from: data)
    }
}

// MARK: - View

struct TrophyRoadView: View {
    let playerId: Int64

    @State private var trophyRanks: [TrophyRank] = []
    @State private var playerPoints: Int = 0

    private let rankService = RankService()
    private let playerService = PlayerLocationService()

    private var currentRank: TrophyRank? {
        trophyRanks.first { $0.range.contains(playerPoints) }
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

                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(trophyRanks.indices.reversed(), id: \.self) { index in
                                    let rank = trophyRanks[index]
                                    rankBox(for: rank)
                                        .id(rank.id)

                                    if index > 0 {
                                        let lowerRank = trophyRanks[index - 1]
                                        etappenBlock(from: lowerRank, to: rank)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                        }
                        .onChange(of: playerPoints) { _ in
                            if let current = currentRank {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    proxy.scrollTo(current.id, anchor: .center)
                                }
                            }
                        }
                        .onAppear {
                            if let current = currentRank {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    proxy.scrollTo(current.id, anchor: .center)
                                }
                            }
                        }
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
        .task {
            await loadData()
        }
    }

    // MARK: - Data loading

    private func loadData() async {
        do {
            async let ranksAsync = rankService.loadRanks()
            async let pointsAsync = playerService.loadPlayerPoints(id: playerId)

            let (ranks, points) = try await (ranksAsync, pointsAsync)

            await MainActor.run {
                self.trophyRanks = ranks
                self.playerPoints = points
            }
        } catch {
            print("Fehler beim Laden von Ranks/Points:", error)
        }
    }


    // MARK: - Rank Box

    private func rankBox(for rank: TrophyRank) -> some View {
        let isCurrentRank = rank.id == currentRank?.id

        return VStack(alignment: .leading, spacing: 8) {
            Text(rank.name.uppercased())
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
                .shadow(radius: 2)

            Text("\(rank.min) – \(rank.max)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.85))

            if isCurrentRank {
                Text("AKTUELL")
                    .font(.system(size: 12, weight: .black))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white))
                    .foregroundColor(rank.uiColor)
                    .shadow(radius: 2)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [rank.uiColor.opacity(0.95), rank.uiColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(28)
        .shadow(color: rank.uiColor.opacity(0.3), radius: 10, y: 6)
        .padding(.vertical, 12)
    }

    // MARK: - Etappen Block

    private func etappenBlock(from lowerRank: TrophyRank, to upperRank: TrophyRank) -> some View {
        let steps = 8
        let stepHeight: CGFloat = 36
        let totalHeight = CGFloat(steps - 1) * stepHeight

        let isCurrentRank = lowerRank.id == currentRank?.id

        let progress: CGFloat = {
            guard isCurrentRank else { return 0 }

            let lower = lowerRank.min
            let upper = lowerRank.max

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

            if isCurrentRank {
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle().stroke(upperRank.uiColor, lineWidth: 3)
                    )
                    .shadow(color: upperRank.uiColor.opacity(0.8), radius: 12)
                    .offset(y: totalHeight / 2 - (progress * totalHeight))
                    .animation(.spring(), value: playerPoints)
            }
        }
        .padding(.vertical, 8)
    }
}
