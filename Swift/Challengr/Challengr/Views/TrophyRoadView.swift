import SwiftUI

// MARK: - Model (Modell)

struct TrophyRank: Identifiable, Codable, Equatable {
    let name: String
    let min: Int
    let max: Int
    let color: String

    var id: String { name }

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
        let (data, _) = try await API.data(from: url)
        return try JSONDecoder().decode([TrophyRank].self, from: data)
    }
}

// MARK: - Trophy Road View (Ansicht)

/// Ein durchgehender Weg von unten (erster Rang) nach oben (Challengr). Die eigene Figur läuft beim Öffnen
/// vom zuletzt gesehenen Stand zum aktuellen; bei einem neuen Rang gibt es eine Feier mit den neuen Figuren.
struct TrophyRoadView: View {
    // MARK: - Input (Eingaben)
    let playerId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State (State)
    @State private var ranks: [TrophyRank] = []
    /// Liga-Trophäen (Quiz-Show und Real-Life gemeinsam)
    @State private var trophies = 0
    /// Persönlicher Rekord (höchster je erreichter Stand)
    @State private var record: Int?
    @State private var unlocks: [String: CharacterUnlockDTO] = [:]
    @State private var loaded = false
    /// Position der Figur auf dem Weg (animiert)
    @State private var walker: Double = 0
    /// Angezeigter Trophäen-Stand (zählt beim Öffnen hoch)
    @State private var shownTrophies = 0
    @State private var rankUp: TrophyRank?
    @State private var showRules = false
    @State private var showLeaderboard = false

    // MARK: - Services (Services)
    private let rankService = RankService()
    private let playerService = PlayerLocationService()
    private let characterService = CharacterService()

    private var road: TrophyRoadMath { TrophyRoadMath(ranks: ranks) }

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        ZStack {
            GameStyle.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if loaded && !ranks.isEmpty {
                    roadScroll
                } else {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
            }

            if let rankUp {
                RankUpOverlay(rank: rankUp, rewards: GameCharacter.rankRewards(atTrophies: rankUp.min)) {
                    withAnimation(.easeOut(duration: 0.25)) { self.rankUp = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                .zIndex(1)
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView(rankColor: { name in ranks.first { $0.name == name }?.uiColor ?? .gray })
        }
        .sheet(isPresented: $showRules) {
            TrophyRulesSheet()
                .presentationDetents([.medium, .large])
        }
        .task { await loadData() }
    }

    // MARK: - Header (Kopfbereich)

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                roundButton("info") { showRules = true }
                    .accessibilityLabel("Regeln")
                Spacer()
                Text("TROPHY ROAD")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Color.challengrYellow)
                Spacer()
                roundButton("xmark") { dismiss() }
            }

            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.challengrYellow)
                    .shadow(color: .challengrYellow.opacity(0.6), radius: 10)
                    .symbolEffect(.bounce, value: shownTrophies)
                Text("\(shownTrophies)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(shownTrophies)))
            }

            if let rank = road.rank(for: trophies) {
                Text(rank.name.uppercased())
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(rank.uiColor))
                    .foregroundStyle(.white)
            }

            if let record, loaded {
                recordChip(record)
            }

            nextRankBar

            // Rangliste (Top 10, Freunde, eigener Platz) – früher eigener Menü-Knopf
            Button {
                SoundManager.shared.play(.click)
                showLeaderboard = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill").foregroundStyle(Color.challengrYellow)
                    Text("RANGLISTE")
                        .tracking(1.2)
                    Spacer()
                    Text("Top 10 · Freunde")
                        .foregroundStyle(GameStyle.secondaryText)
                    Image(systemName: "chevron.right").foregroundStyle(GameStyle.secondaryText)
                }
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .gamePanel(padding: 12, cornerRadius: 16)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    /// Persönlicher Rekord – zeigt, wie weit man schon einmal war (und dass Verluste nicht alles wegnehmen).
    private func recordChip(_ record: Int) -> some View {
        let isNow = record <= trophies
        return HStack(spacing: 5) {
            Image(systemName: isNow ? "flame.fill" : "star.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color.challengrYellow)
            Text("REKORD \(record.formatted())")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.85))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(GameStyle.panelFill))
        .overlay(Capsule().stroke(Color.challengrYellow.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Persönlicher Rekord: \(record) Trophäen\(isNow ? ", du bist gerade drauf" : "")")
    }

    private func roundButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(GameStyle.panelFill))
                .overlay(Circle().stroke(GameStyle.panelStroke, lineWidth: 1))
        }
    }

    /// Balken bis zum nächsten Rang, inkl. der Figur, die dort wartet.
    @ViewBuilder
    private var nextRankBar: some View {
        if loaded, !ranks.isEmpty {
            let fraction = walker - floor(walker)
            let next = road.nextRank(after: trophies)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let next, let missing = road.trophiesToNextRank(trophies) {
                        Text("Noch \(missing) bis \(next.name)")
                        if let reward = GameCharacter.rankRewards(atTrophies: next.min).first {
                            Spacer()
                            Image(reward.avatarImageName)
                                .resizable().scaledToFill()
                                .frame(width: 22, height: 22)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(next.uiColor, lineWidth: 1.5))
                            Text(reward.displayName)
                        }
                    } else {
                        Text("Höchster Rang erreicht – nach oben offen!")
                    }
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(GameStyle.secondaryText)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(LinearGradient(colors: [.challengrYellow, .orange],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: Swift.max(10, geo.size.width * (next == nil ? 1 : fraction)))
                            .shadow(color: .challengrYellow.opacity(0.6), radius: 6)
                    }
                }
                .frame(height: 10)
            }
            .gamePanel(padding: 12, cornerRadius: 16)
        }
    }

    // MARK: - Road (Weg)

    private var roadScroll: some View {
        GeometryReader { outer in
            let geo = RoadGeometry(width: outer.size.width, ranks: ranks.count)
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .top) {
                        RoadCanvas(geo: geo,
                                   ranks: road.ranks,
                                   currentIndex: road.rankIndex(for: trophies) ?? 0,
                                   walker: walker,
                                   animate: !reduceMotion,
                                   isUnlocked: isUnlocked)
                        // Unsichtbare Markierungen alle `scrollSlice` Punkt – Ziele für scrollTo (auch unter iOS 17)
                        VStack(spacing: 0) {
                            ForEach(0..<Int(ceil(geo.height / Self.scrollSlice)), id: \.self) { i in
                                Color.clear.frame(height: Self.scrollSlice).id(i)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
                .defaultScrollAnchor(.bottom)
                .task(id: loaded) {
                    guard loaded else { return }
                    await walkIn(geo: geo, proxy: proxy)
                }
            }
        }
    }

    private func isUnlocked(_ character: GameCharacter, rankIndex: Int) -> Bool {
        unlocks[character.rawValue]?.unlocked ?? (rankIndex <= (road.rankIndex(for: trophies) ?? -1))
    }

    // MARK: - Actions (Aktionen)

    /// Figur vom zuletzt gesehenen Stand zum aktuellen laufen lassen; bei neuem Rang feiern.
    private static let scrollSlice: CGFloat = 50

    /// Scrollt so, dass die Figur bei dieser Weg-Position in der Mitte des Bildschirms steht.
    private func scrollToWalker(at position: Double, geo: RoadGeometry, proxy: ScrollViewProxy) {
        proxy.scrollTo(Int(geo.point(position).y / Self.scrollSlice), anchor: .center)
    }

    private func walkIn(geo: RoadGeometry, proxy: ScrollViewProxy) async {
        let math = road
        let last = TrophyRoadMemory.lastSeen(playerId: playerId)
        // Erster Besuch: vom Anfang des aktuellen Rangs loslaufen, ohne Feier
        let start = last ?? math.rank(for: trophies)?.min ?? 0
        TrophyRoadMemory.remember(trophies, playerId: playerId)

        walker = math.position(for: start)
        shownTrophies = start
        // Direkt beim eigenen Stand starten (Mitte zwischen alter und neuer Position, damit beide sichtbar sind)
        try? await Task.sleep(for: .milliseconds(30))
        scrollToWalker(at: (math.position(for: start) + math.position(for: trophies)) / 2, geo: geo, proxy: proxy)

        guard !reduceMotion else {
            walker = math.position(for: trophies)
            shownTrophies = trophies
            return
        }

        try? await Task.sleep(for: .milliseconds(450))
        let duration = start == trophies ? 0.0 : 1.6
        withAnimation(.easeInOut(duration: duration)) {
            walker = math.position(for: trophies)
            shownTrophies = trophies
        }

        if let old = math.rankIndex(for: start), let new = math.rankIndex(for: trophies), new > old {
            try? await Task.sleep(for: .seconds(duration))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                rankUp = math.ranks[new]
            }
        }
    }

    private func loadData() async {
        do {
            async let ranksAsync = rankService.loadRanks()
            async let pointsAsync = playerService.loadPlayerPoints(id: playerId)
            async let playerAsync = try? playerService.loadPlayerById(id: playerId)
            async let unlocksAsync = try? characterService.loadCharacters(playerId: playerId)

            let (loadedRanks, points) = try await (ranksAsync, pointsAsync)
            let player = await playerAsync
            let list = await unlocksAsync ?? []

            ranks = loadedRanks
            // Alte Server ohne Liga: Punkte wie bisher
            trophies = player?.trophies ?? points
            record = player?.highestTrophies.map { Swift.max($0, trophies) }
            unlocks = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            loaded = true
        } catch {
            print("Fehler beim Laden:", error)
        }
    }
}

// MARK: - Road geometry (Weg-Geometrie)

/// Schlängelweg: Ränge liegen abwechselnd rechts und links außen, dazwischen kreuzt der Weg die Mitte.
private struct RoadGeometry {
    let width: CGFloat
    let ranks: Int
    let segment: CGFloat = 250
    let top: CGFloat = 150
    let bottom: CGFloat = 110

    var height: CGFloat { CGFloat(ranks) * segment + top + bottom }
    var amplitude: CGFloat { width * 0.24 }

    func point(_ u: Double) -> CGPoint {
        CGPoint(x: width / 2 + CGFloat(cos(u * .pi)) * amplitude,
                y: height - bottom - CGFloat(u) * segment)
    }

    /// Rang i liegt rechts (gerade) oder links (ungerade) – die Karte steht auf der anderen Seite.
    func milestoneOnRight(_ index: Int) -> Bool { index % 2 == 0 }
}

/// Weg von 0 bis `to` – animierbar, damit der goldene Fortschritt mit der Figur mitwächst.
private struct RoadShape: Shape {
    let geo: RoadGeometry
    var to: Double

    var animatableData: Double {
        get { to }
        set { to = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: geo.point(0))
            var u = 0.0
            while u < to {
                u = Swift.min(u + 0.03, to)
                p.addLine(to: geo.point(u))
            }
        }
    }
}

/// Setzt einen View an eine Stelle auf dem Weg – animiert entlang der Kurve statt quer darüber.
private struct RoadFollower: ViewModifier, Animatable {
    let geo: RoadGeometry
    var u: Double

    var animatableData: Double {
        get { u }
        set { u = newValue }
    }

    func body(content: Content) -> some View {
        content.position(geo.point(u))
    }
}

// MARK: - Road canvas (Weg mit Rängen und Figur)

private struct RoadCanvas: View {
    let geo: RoadGeometry
    let ranks: [TrophyRank]
    let currentIndex: Int
    let walker: Double
    let animate: Bool
    let isUnlocked: (GameCharacter, Int) -> Bool

    var body: some View {
        ZStack {
            // Fahrbahn
            RoadShape(geo: geo, to: Double(ranks.count))
                .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
            RoadShape(geo: geo, to: Double(ranks.count))
                .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 10]))

            // Geschaffter Weg in Gold
            RoadShape(geo: geo, to: walker)
                .stroke(LinearGradient(colors: [.orange, .challengrYellow], startPoint: .bottom, endPoint: .top),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                .shadow(color: .challengrYellow.opacity(0.7), radius: 8)

            goal

            ForEach(ranks.indices, id: \.self) { i in
                milestone(i)
            }

            walkerFigure
        }
        .frame(width: geo.width, height: geo.height)
    }

    // MARK: Ziel ganz oben

    private var goal: some View {
        VStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.challengrYellow)
                .shadow(color: .challengrYellow.opacity(0.8), radius: 14)
                .modifier(Pulse(active: animate, scale: 1.12))
            Text("NACH OBEN OFFEN")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(GameStyle.secondaryText)
        }
        .position(x: geo.point(Double(ranks.count)).x, y: geo.point(Double(ranks.count)).y - 36)
    }

    // MARK: Rang-Station

    private func milestone(_ i: Int) -> some View {
        let rank = ranks[i]
        let reached = i <= currentIndex
        let isCurrent = i == currentIndex
        let p = geo.point(Double(i))
        let onRight = geo.milestoneOnRight(i)
        let cardWidth = geo.width / 2 + geo.amplitude - 64

        return ZStack {
            // Station auf dem Weg
            ZStack {
                if isCurrent && animate {
                    Circle()
                        .stroke(rank.uiColor, lineWidth: 3)
                        .frame(width: 52, height: 52)
                        .phaseAnimator([false, true]) { view, on in
                            view.scaleEffect(on ? 1.5 : 1).opacity(on ? 0 : 0.9)
                        } animation: { on in on ? .easeOut(duration: 1.4) : .linear(duration: 0) }
                }
                Circle()
                    .fill(reached
                          ? AnyShapeStyle(LinearGradient(colors: [rank.uiColor, rank.uiColor.opacity(0.7)],
                                                          startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color(white: 0.22)))
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(Color.white.opacity(reached ? 0.8 : 0.2), lineWidth: 2))
                    .shadow(color: reached ? rank.uiColor.opacity(0.7) : .clear, radius: 10)
                Image(systemName: reached ? "trophy.fill" : "lock.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(reached ? .white : Color.white.opacity(0.45))
            }
            .position(p)

            // Karte auf der anderen Seite
            rankCard(rank, index: i, reached: reached, isCurrent: isCurrent)
                .frame(width: cardWidth)
                .position(x: onRight ? 16 + cardWidth / 2 : geo.width - 16 - cardWidth / 2, y: p.y)
        }
    }

    private func rankCard(_ rank: TrophyRank, index: Int, reached: Bool, isCurrent: Bool) -> some View {
        let rewards = GameCharacter.rankRewards(atTrophies: rank.min)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(rank.name.uppercased())
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(reached ? rank.uiColor : Color.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if isCurrent {
                    Text("DU")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(rank.uiColor))
                        .foregroundStyle(.white)
                }
            }
            Text("ab \(rank.min) Trophäen")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(GameStyle.secondaryText)

            ForEach(rewards) { character in
                rewardRow(character, unlocked: isUnlocked(character, index), color: rank.uiColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gamePanel(padding: 10, cornerRadius: 16, highlight: isCurrent ? rank.uiColor : nil)
        .opacity(reached ? 1 : 0.75)
    }

    private func rewardRow(_ character: GameCharacter, unlocked: Bool, color: Color) -> some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Image(character.avatarImageName)
                    .resizable().scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(unlocked ? color : Color.white.opacity(0.25), lineWidth: 2))
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.6)
                Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(unlocked ? Color.challengrGreen : Color.white.opacity(0.7))
                    .background(Circle().fill(Color.black))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(character.displayName)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(unlocked ? "Freigeschaltet" : "Neue Figur")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(unlocked ? Color.challengrGreen : GameStyle.secondaryText)
            }
        }
    }

    // MARK: Eigene Figur

    private var walkerFigure: some View {
        VStack(spacing: -6) {
            Image(AvatarPresets.persistedImageName())
                .resizable()
                .scaledToFit()
                .frame(width: 66, height: 66)
                .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
                .modifier(Bob(active: animate))
            Ellipse()
                .fill(Color.black.opacity(0.45))
                .frame(width: 34, height: 9)
                .blur(radius: 2)
        }
        .offset(y: -30)
        .modifier(RoadFollower(geo: geo, u: walker))
    }
}

// MARK: - Kleine Animationen

/// Figur wippt auf der Stelle.
private struct Bob: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([false, true]) { view, up in
                view.offset(y: up ? -5 : 0).rotationEffect(.degrees(up ? 2 : -2))
            } animation: { _ in .easeInOut(duration: 0.55) }
        } else {
            content
        }
    }
}

/// Sanftes Pulsieren (z.B. Krone).
private struct Pulse: ViewModifier {
    let active: Bool
    let scale: CGFloat

    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([false, true]) { view, on in
                view.scaleEffect(on ? scale : 1)
            } animation: { _ in .easeInOut(duration: 1.1) }
        } else {
            content
        }
    }
}

// MARK: - Rang-Aufstieg

private struct RankUpOverlay: View {
    let rank: TrophyRank
    let rewards: [GameCharacter]
    let onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .onTapGesture(perform: onClose)

            ConfettiBurst(colors: [rank.uiColor, .challengrYellow, .white, .orange])

            VStack(spacing: 14) {
                Text("NEUER RANG!")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Color.challengrYellow)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(rank.uiColor)
                    .shadow(color: rank.uiColor.opacity(0.9), radius: 20)
                    .symbolEffect(.bounce, value: appeared)

                Text(rank.name.uppercased())
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                ForEach(rewards) { character in
                    VStack(spacing: 4) {
                        Image(character.imageName)
                            .resizable().scaledToFit()
                            .frame(height: 120)
                            .shadow(color: rank.uiColor.opacity(0.8), radius: 16)
                            .scaleEffect(appeared ? 1 : 0.3)
                        Text("\(character.displayName) freigeschaltet!")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.challengrGreen)
                    }
                }

                Button(action: onClose) {
                    Text("Weiter")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.challengrDark)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.challengrYellow))
                }
                .padding(.top, 6)
            }
            .padding(28)
            .gamePanel(padding: 0, cornerRadius: 28, highlight: rank.uiColor)
            .background(RoundedRectangle(cornerRadius: 28).fill(Color.challengrDark))
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.15)) { appeared = true }
        }
    }
}

/// Konfetti, das einmal aus der Mitte fliegt (Werte fest pro Teilchen, damit nichts springt).
private struct ConfettiBurst: View {
    let colors: [Color]
    @State private var fired = false

    var body: some View {
        ZStack {
            ForEach(0..<36, id: \.self) { i in
                let angle = Double(i) / 36 * 2 * .pi + sin(Double(i) * 12.9898) * 0.3
                let distance = 160 + abs(sin(Double(i) * 78.233)) * 160
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[i % colors.count])
                    .frame(width: 7, height: 13)
                    .rotationEffect(.degrees(fired ? Double(i * 47 % 360) + 540 : 0))
                    .offset(x: fired ? cos(angle) * distance : 0,
                            y: fired ? sin(angle) * distance + 120 : 0)
                    .opacity(fired ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.8)) { fired = true }
        }
    }
}

// MARK: - Regeln

private struct TrophyRulesSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("So funktionieren Trophäen")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                rule("equal", "Gleich stark", "Sieg +30, Niederlage −20 – wenn beide gleich viele Trophäen haben.")
                rule("arrow.up.right", "Gegen Stärkere", "Pro 25 Trophäen, die dein Gegner mehr hat, gibt’s für einen Sieg 1 mehr – und eine Niederlage kostet 1 weniger.")
                rule("arrow.down.right", "Gegen Schwächere", "Umgekehrt: ein Sieg bringt weniger, eine Niederlage kostet mehr.")
                rule("shield.lefthalf.filled", "Grenzen", "Ein Sieg bringt 10 bis 50, eine Niederlage kostet höchstens 40. Unter 0 fällst du nie.")
                rule("equal.circle", "Unentschieden & Friendly", "Keine Trophäen – Friendly-Battles zählen nie für die Liga.")
                rule("person.crop.circle.badge.checkmark", "Rang-Figuren", "Manche Figuren gibt’s nur auf der Trophy Road. Einmal erreicht, bleiben sie dir – auch wenn du wieder abrutschst.")
            }
            .padding(24)
        }
        .background(GameStyle.background.ignoresSafeArea())
    }

    private func rule(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.challengrYellow)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(GameStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gamePanel(padding: 12, cornerRadius: 16)
    }
}
