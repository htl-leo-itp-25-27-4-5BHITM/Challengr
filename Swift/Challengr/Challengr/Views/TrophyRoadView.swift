import SwiftUI

// MARK: - Model (Modell)

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

// MARK: - Service (Service)

final class RankService {
    private let baseURL = BackendConfig.baseURL

    func loadRanks() async throws -> [TrophyRank] {
        let url = baseURL.appendingPathComponent("api/ranks")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([TrophyRank].self, from: data)
    }
}

// MARK: - Trophy Road View (Ansicht)

struct TrophyRoadView: View {
    // MARK: - Input (Eingaben)
    let playerId: Int64

    // MARK: - State (State)
    @State private var trophyRanks: [TrophyRank] = []
    @State private var playerPoints: Int = 0

    // MARK: - Services (Services)
    private let rankService = RankService()
    private let playerService = PlayerLocationService()

    // MARK: - Derived values (Abgeleitete Werte)
    private var currentRank: TrophyRank? {
        trophyRanks.first { $0.range.contains(playerPoints) }
    }

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 16) {
                    Spacer(minLength: 8)

                    header

                    mainCard

                    Spacer(minLength: 16)
                }

                infoButton
            }
        }
        .task { await loadData() }
    }

    // MARK: - Background (Hintergrund)

    private var background: some View {
        LinearGradient(
            colors: [Color(.systemGray6), Color(.systemGray5)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header (Kopfbereich)

    private var header: some View {
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
    }

    // MARK: - Main Card (Hauptkarte)

    private var mainCard: some View {
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
                        VStack(spacing: 24) {
                            // höchste Ranks oben
                            ForEach(trophyRanks.indices.reversed(), id: \.self) { index in
                                let rank = trophyRanks[index]

                                RankSectionView(
                                    rank: rank,
                                    isCurrent: rank.id == currentRank?.id,
                                    playerPoints: playerPoints,
                                    previousRank: index > 0 ? trophyRanks[index - 1] : nil
                                )
                                .id(rank.id)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                    }
                    .onAppear {
                        scrollToCurrentRank(with: proxy)
                    }
                    .onChange(of: playerPoints) { _ in
                        scrollToCurrentRank(with: proxy)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Info Button (Info-Button)

    private var infoButton: some View {
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

    // MARK: - Actions (Aktionen)

    private func scrollToCurrentRank(with proxy: ScrollViewProxy) {
        if let current = currentRank {
            withAnimation(.easeOut(duration: 0.5)) {
                proxy.scrollTo(current.id, anchor: .center)
            }
        }
    }

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
            print("Fehler beim Laden:", error)
        }
    }
}

// MARK: - Rank Section (Pfad + Card + Figur)

private struct RankSectionView: View {
    let rank: TrophyRank
    let isCurrent: Bool
    let playerPoints: Int
    let previousRank: TrophyRank?

    private let steps = 7           // weniger, dafür „wuchtiger“
    private let stepHeight: CGFloat = 34

    var body: some View {
        VStack(spacing: 10) {
            pathWithCharacter
            rankCard
        }
    }

    // MARK: Pfad + Figur über der Card
    private var pathWithCharacter: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack {
                // Hintergrund-Glow
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                rank.uiColor.opacity(0.18),
                                rank.uiColor.opacity(0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blur(radius: 8)

                // Hauptpfad
                Path { path in
                    for i in 0..<steps {
                        let t = CGFloat(i) / CGFloat(max(steps - 1, 1))

                        // sanfter S‑Schwung wie in Clash Royale
                        let xSin = sin(t * .pi)
                        let x = width / 2 + xSin * (width * 0.28)
                        let y = CGFloat(i) * stepHeight + 10

                        let point = CGPoint(x: x, y: y)

                        if i == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            rank.uiColor.opacity(0.95),
                            rank.uiColor.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: rank.uiColor.opacity(0.7), radius: 6, x: 0, y: 2)

                // Nodes mit farbigem Kern + subtilerem Glow
                ForEach(0..<steps, id: \.self) { i in
                    let t = CGFloat(i) / CGFloat(max(steps - 1, 1))
                    let xSin = sin(t * .pi)
                    let x = width / 2 + xSin * (width * 0.28)
                    let y = CGFloat(i) * stepHeight + 10

                    ZStack {
                        // weicher Glow-Hintergrund
                        Circle()
                            .fill(rank.uiColor.opacity(0.35))
                            .frame(width: 26, height: 26)
                            .blur(radius: 1.5)

                        // eigentlicher Node
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        rank.uiColor,
                                        rank.uiColor.opacity(0.8)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)

                        // kleines Reward-Icon für jeden zweiten Node
                        if i % 2 == 0 {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                        }
                    }
                    .position(x: x, y: y)
                }


                // Figur im aktuellen Rank
                if isCurrent {
                    let slot = currentSlot()
                    let t = CGFloat(slot) / CGFloat(max(steps - 1, 1))
                    let xSin = sin(t * .pi)
                    let x = width / 2 + xSin * (width * 0.28)
                    let y = CGFloat(slot) * stepHeight + 10

                    Image("playerBoy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                        .position(x: x, y: y - 26)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: slot)
                }
            }
        }
        .frame(height: CGFloat(steps - 1) * stepHeight + 48)
    }

    // Slot-Berechnung (0..steps-1), v.a. untere Hälfte des Pfads nutzen
    private func currentSlot() -> Int {
        let lower = rank.min
        let upper = rank.max
        let clamped = max(min(playerPoints, upper), lower)
        let raw = CGFloat(clamped - lower) / CGFloat(max(upper - lower, 1)) // 0..1

        var idx = Int((raw * CGFloat(steps)).rounded(.down)) // 0..steps-1

        // Figur eher in der unteren/mittleren Region halten
        let minSlot = 0          // direkt an der Card möglich
        let maxSlot = steps - 1  // z.B. bis drei Slots vor Ende
        idx = max(maxSlot, min(minSlot, idx))

        return idx
    }

    // MARK: Card des Ranks

    private var rankCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                Color.white.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 42, height: 42)
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(rank.uiColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(rank.name.uppercased())
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("\(rank.min) – \(rank.max) PUNKTE")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                if isCurrent {
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

            if isCurrent {
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
                    rank.uiColor.opacity(0.98),
                    rank.uiColor.opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
        )
        .cornerRadius(26)
        .shadow(color: rank.uiColor.opacity(0.4), radius: 14, x: 0, y: 8)
    }
}

