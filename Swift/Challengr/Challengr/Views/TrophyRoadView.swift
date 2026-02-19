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
        case "red":    return .challengrRed
        case "green":  return .challengrGreen
        case "yellow": return .challengrYellow
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
                // Hintergrund
                LinearGradient(
                    colors: [
                        Color(.systemGray6),
                        Color(.systemGray5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    Spacer(minLength: 8)

                    // Kopfbereich
                    VStack(spacing: 12) {
                        Text("TROPHY ROAD")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .tracking(3)
                            .foregroundColor(.challengrRed.opacity(0.9))

                        if let currentRank {
                            Text(currentRank.name.uppercased())
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.challengrBlack)

                            Text("\(playerPoints) TROPHÄEN")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.challengrBlack.opacity(0.7))
                        } else {
                            Text("\(playerPoints) TROPHÄEN")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.challengrBlack.opacity(0.7))
                        }
                    }

                    // Haupt-Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 16)

                        RoundedRectangle(cornerRadius: 32)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.challengrYellow.opacity(0.5),
                                        Color.challengrRed.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )

                        VStack(spacing: 16) {
                            Text("DEINE RANGLISTE")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .tracking(2)
                                .foregroundColor(.challengrBlack.opacity(0.5))
                                .padding(.top, 16)

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
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 28)
                                }
                                .onChange(of: playerPoints) { _ in
                                    scrollToCurrentRank(with: proxy)
                                }
                                .onAppear {
                                    scrollToCurrentRank(with: proxy)
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 16)
                }

                // Info-Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink(destination: ChallengeView()) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.challengrBlack)
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                                )
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

    // MARK: - Scroll helper

    private func scrollToCurrentRank(with proxy: ScrollViewProxy) {
        if let current = currentRank {
            withAnimation(.easeOut(duration: 0.5)) {
                proxy.scrollTo(current.id, anchor: .center)
            }
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

    // MARK: - Rank Box (gerade Spalte)

    private func rankBox(for rank: TrophyRank) -> some View {
        let isCurrentRank = rank.id == currentRank?.id

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(rank.name.uppercased())
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("\(rank.min) – \(rank.max) PUNKTE")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                if isCurrentRank {
                    Text("AKTUELLER RANG")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                        .foregroundColor(rank.uiColor)
                }
            }

            Spacer()

            if isCurrentRank {
                Text("\(playerPoints)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    rank.uiColor.opacity(0.95),
                    rank.uiColor.opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: rank.uiColor.opacity(0.35), radius: 12, x: 0, y: 8)
        .padding(.vertical, 10)
    }

    // MARK: - Etappen Block (kurvige Steps + springende Figur)

    private func etappenBlock(from lowerRank: TrophyRank, to upperRank: TrophyRank) -> some View {
        let steps = 10
        let stepHeight: CGFloat = 32
        let totalHeight = CGFloat(steps - 1) * stepHeight

        let isCurrentRank = lowerRank.id == currentRank?.id

        // Fortschritt innerhalb dieses Ranks 0–1
        let progress: CGFloat = {
            guard isCurrentRank else { return 0 }

            let lower = lowerRank.min
            let upper = lowerRank.max
            let clamped = max(min(playerPoints, upper), lower)

            return CGFloat(clamped - lower) / CGFloat(max(upper - lower, 1))
        }()

        return GeometryReader { geo in
            let width = geo.size.width

            ZStack {
                // Kurvige Linie
                Path { path in
                    for i in 0..<steps {
                        let t = CGFloat(i) / CGFloat(max(steps - 1, 1))

                        let xSin = sin(t * .pi * 2)          // -1…1
                        let x = width / 2 + xSin * (width * 0.22)
                        let y = CGFloat(i) * stepHeight

                        let point = CGPoint(x: x, y: y)

                        if i == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(
                    lowerRank.uiColor.opacity(0.5),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                )


                // Steps – in Rank-Farbe
                ForEach(0..<steps, id: \.self) { i in
                    let t = CGFloat(i) / CGFloat(max(steps - 1, 1))
                    let xSin = sin(t * .pi * 2)
                    let x = width / 2 + xSin * (width * 0.22)
                    let y = CGFloat(i) * stepHeight

                    Circle()
                        .fill(lowerRank.uiColor)                          // Farbe vom Rank
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                        )
                        .frame(width: 14, height: 14)
                        .shadow(color: lowerRank.uiColor.opacity(0.4), radius: 3, x: 0, y: 1)
                        .position(x: x, y: y)
                }


                // Figur springt von Punkt zu Punkt im aktuellen Rank
                if isCurrentRank {
                    // Index des aktuellen Steps (0…steps-1)
                    let stepIndex = Int(round(progress * CGFloat(steps - 1)))
                    let t = CGFloat(stepIndex) / CGFloat(max(steps - 1, 1))

                    let xSin = sin(t * .pi * 2)
                    let x = width / 2 + xSin * (width * 0.22)
                    let y = CGFloat(stepIndex) * stepHeight

                    Image("playerBoy") // deine Figur
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                        .position(x: x, y: y - 20) // leicht über dem Punkt
                        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: stepIndex)
                }
            }
        }
        .frame(height: CGFloat(steps) * stepHeight)
        .padding(.vertical, 8)
    }
}
