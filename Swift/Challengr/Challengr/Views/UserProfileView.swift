//
//  UserProfileView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 04.03.26.
//
import SwiftUI
import Charts

// MARK: - Models (Modelle)

struct UserProfileData {
    let name: String
    let avatarImageName: String
    let rankName: String
    let dailyStreak: Int
    let totalChallenges: Int
    let wonChallenges: Int
    let points: Int
    /// Liga-Stände (nil bei alten Servern)
    /// Liga-Trophäen (nil bei alten Servern)
    var trophies: Int? = nil
}

struct ProfileBadge {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - View (UI)

struct UserProfileView: View {
    var playerId: String = ""
    let data: UserProfileData
    let battleHistory: [BattleHistoryDTO]
    let profileStatusText: String?
    let profileBadges: [String]
    var rankColor: Color = .gray

    @State private var selectedDate: String? = nil
    @State private var selectedTrophies: Int? = nil
    @State private var isChartExpanded: Bool = true
    @State private var showCharacterEditor: Bool = false

    @StateObject private var avatarStore = AvatarCustomizationStore()

    // MARK: - Body (Aufbau)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                profileHero

                HStack(spacing: 10) {
                    GameStatTile(icon: "flame.fill", value: "\(data.dailyStreak)", title: "Streak", color: .orange)
                    GameStatTile(icon: "flag.checkered", value: "\(data.totalChallenges)", title: "Challenges", color: .white)
                    GameStatTile(icon: "trophy.fill", value: "\(data.wonChallenges)", title: "Siege", color: .challengrYellow)
                    GameStatTile(icon: "percent", value: winRateText, title: "Siegquote", color: .challengrGreen)
                }

                leagueSection

                trophyChart

                badgesSection

                battleDetailList(for: selectedDate)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(GameStyle.background.ignoresSafeArea())
        .sheet(isPresented: $showCharacterEditor, onDismiss: { avatarStore.load() }) {
            CharacterEditorSheet(store: avatarStore, playerId: playerId)
        }
    }

    // MARK: - Liga (Trophäen)

    @ViewBuilder
    private var leagueSection: some View {
        if let trophies = data.trophies {
            HStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.challengrYellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIGA")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(GameStyle.secondaryText)
                    Text("\(trophies) Trophäen")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Quiz-Show und Real-Life zählen zusammen")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(GameStyle.secondaryText)
                }
                Spacer(minLength: 0)
                Text(data.rankName.uppercased())
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.challengrDark)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(rankColor))
            }
            .gamePanel(padding: 14, cornerRadius: 18, highlight: .challengrYellow)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Hero (Figur, Name, Rang)

    private var winRateText: String {
        guard data.totalChallenges > 0 else { return "–" }
        return "\(Int((Double(data.wonChallenges) / Double(data.totalChallenges) * 100).rounded()))%"
    }

    /// Bühne mit der eigenen 3D-Figur (zum Drehen wischen), darunter Name, Rang und Punkte.
    private var profileHero: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(RadialGradient(colors: [rankColor.opacity(0.55), Color.challengrDark.opacity(0.9)],
                                     center: .top, startRadius: 10, endRadius: 300))
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(rankColor.opacity(0.6), lineWidth: 2)

            VStack(spacing: 8) {
                Character3DView(character: avatarStore.selectedPreset.character ?? .current, allowsDragRotation: true)
                    .frame(height: 210)
                    .accessibilityLabel("Deine Figur")
                    .accessibilityHint("Zum Drehen wischen")

                Text(data.name.uppercased())
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 8) {
                    Text(data.rankName.uppercased())
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.challengrDark)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(rankColor))
                    Label("\(data.trophies ?? 0)", systemImage: "trophy.fill")
                        .accessibilityLabel("\(data.trophies ?? 0) Trophäen")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.challengrYellow)
                    statusChip
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(height: 340)
        .overlay(alignment: .topTrailing) {
            GamePillButton(icon: "paintbrush.pointed.fill", title: "Figur") {
                showCharacterEditor = true
            }
            .padding(14)
        }
    }

    // MARK: - Trophy chart (Trophäenverlauf)

    private var trophyChart: some View {
        let sortedHistory = TrophyHistory.daily(battles: battleHistory, current: data.trophies ?? 0)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TROPHÄENVERLAUF")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isChartExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isChartExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }

            if sortedHistory.isEmpty {
                Text("Noch keine Liga-Battles")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else if isChartExpanded {
                Chart(sortedHistory) { entry in
                    LineMark(
                        x: .value("Datum", entry.date),
                        y: .value("Trophäen", entry.trophies)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, Color.challengrYellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    PointMark(
                        x: .value("Datum", entry.date),
                        y: .value("Trophäen", entry.trophies)
                    )
                    .foregroundStyle(entry.date == selectedDate ? Color.challengrYellow : Color.accentColor)
                    .symbolSize(entry.date == selectedDate ? 90 : 40)
                }
                .frame(height: 150)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        let plotFrame = geometry[proxy.plotAreaFrame]
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let relativeX = value.location.x - plotFrame.minX
                                        if let date: String = proxy.value(atX: relativeX) {
                                            selectedDate = date
                                            selectedTrophies = sortedHistory.first { $0.date == date }?.trophies
                                        }
                                    }
                            )
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        if let selectedDate,
                           let selectedTrophies,
                           let xPosition = proxy.position(forX: selectedDate),
                           let yPosition = proxy.position(forY: selectedTrophies) {
                            let plotFrame = geometry[proxy.plotAreaFrame]
                            let point = CGPoint(x: xPosition + plotFrame.minX, y: yPosition + plotFrame.minY)

                            Circle()
                                .fill(Color.challengrYellow)
                                .frame(width: 10, height: 10)
                                .position(point)

                            VStack(spacing: 2) {
                                Text(selectedDate)
                                    .font(.caption2.weight(.semibold))
                                Text("\(selectedTrophies) Trophäen")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(GameStyle.panelFill)
                                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                            )
                            .offset(x: -6, y: -36)
                            .position(point)
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        if let selectedDate,
                           let xPosition = proxy.position(forX: selectedDate) {
                            let plotFrame = geometry[proxy.plotAreaFrame]
                            let xPoint = xPosition + plotFrame.minX

                            Path { path in
                                path.move(to: CGPoint(x: xPoint, y: plotFrame.minY))
                                path.addLine(to: CGPoint(x: xPoint, y: plotFrame.maxY))
                            }
                            .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GameStyle.panelFill)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .padding(.top, 12)
    }

    // MARK: - Status & badges (Status & Badges)

    private var statusChip: some View {
        let status = profileStatus
        return HStack(spacing: 6) {
            Circle()
                .fill(status.isOnline ? Color.challengrGreen : Color.gray)
                .frame(width: 8, height: 8)
            Text(status.text)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(GameStyle.panelFill)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }

    private var badgesSection: some View {
        let badges = resolvedBadges

        return VStack(alignment: .leading, spacing: 10) {
            Text("BADGES")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundColor(.secondary)

            if badges.isEmpty {
                Text("Noch keine Badges")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(badges, id: \.title) { badge in
                        HStack(spacing: 8) {
                            Image(systemName: badge.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(badge.color)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(badge.title)
                                    .font(.caption.weight(.semibold))
                                Text(badge.subtitle)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(GameStyle.panelFill)
                                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GameStyle.panelFill)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }

    // MARK: - Battle list (Battle-Liste)

    private func battleDetailList(for date: String?) -> some View {
        let filtered = battleHistory.filter { battle in
            guard let date else { return true }
            return battle.createdAt.hasPrefix(date)
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(filteredTitle(for: date))
                        .font(.system(size: 16, weight: .bold))
                    Text(date == nil ? "Tippe auf einen Punkt im Graphen" : "Nur Challenges dieses Tages")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if date != nil {
                    Button("Alles anzeigen") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = nil
                            selectedTrophies = nil
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentColor)
                }
            }

            legendView

            if filtered.isEmpty {
                Text(date == nil ? "Noch keine Battles" : "Keine Battles an diesem Tag")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(filtered) { battle in
                    let deltaColor: Color = battle.pointsDelta >= 0 ? .challengrGreen : .challengrRed
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: categoryIcon(for: battle.category))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(categoryColor(for: battle.category))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(battle.challengeText)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("Gegner: \(battle.opponentName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(battle.category)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(categoryColor(for: battle.category).opacity(0.18))
                                .foregroundColor(categoryColor(for: battle.category))
                                .clipShape(Capsule())
                        }

                        HStack(spacing: 8) {
                            Text(battle.won ? "Gewonnen" : battle.isDraw ? "Unentschieden" : "Verloren")
                                .font(.caption)
                                .foregroundColor(battle.won ? .challengrGreen : battle.isDraw ? .secondary : .challengrRed)

                            Text("Δ \(battle.pointsDelta)")
                                .font(.caption)
                                .foregroundColor(deltaColor)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(GameStyle.panelFill)
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GameStyle.panelFill)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .padding(.top, 8)
    }

    // MARK: - Helpers (Hilfsfunktionen)

    private func filteredTitle(for date: String?) -> String {
        if let date {
            return "Battles am \(date)"
        }
        return "Alle Battles"
    }

    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "wissen":
            return "book.closed"
        case "fitness":
            return "figure.run"
        case "mutprobe":
            return "flame"
        case "iphone":
            return "iphone"
        case "customer":
            return "person.2"
        default:
            return "flag.checkered"
        }
    }

    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "wissen":
            return .challengrGreen
        case "fitness":
            return .challengrYellow
        case "mutprobe":
            return .challengrRed
        case "iphone":
            return .blue
        case "customer":
            return .purple
        default:
            return .secondary
        }
    }

    private var profileStatus: (text: String, isOnline: Bool) {
        if let statusText = profileStatusText, !statusText.isBlank {
            let isOnline = statusText.lowercased() == "online"
            return (statusText, isOnline)
        }
        guard let lastBattleDate = battleHistory
            .compactMap({ parseDate($0.createdAt) })
            .sorted()
            .last else {
            return ("Noch keine Aktivität", false)
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(lastBattleDate) {
            return ("Online", true)
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return ("Zuletzt aktiv: \(formatter.string(from: lastBattleDate))", false)
    }

    private var resolvedBadges: [ProfileBadge] {
        if !profileBadges.isEmpty {
            return profileBadges.compactMap { badgeForCode($0) }
        }

        let totalBattles = battleHistory.count
        let wins = battleHistory.filter { $0.won }.count
        let winStreak = currentWinStreak

        var badges: [ProfileBadge] = []

        if wins >= 1 {
            badges.append(ProfileBadge(title: "Erster Sieg", subtitle: "1 Battle gewonnen", icon: "star.fill", color: .challengrYellow))
        }
        if wins >= 3 {
            badges.append(ProfileBadge(title: "Siegeszug", subtitle: "3 Siege", icon: "flame.fill", color: .challengrRed))
        }
        if totalBattles >= 5 {
            badges.append(ProfileBadge(title: "Aktiv", subtitle: "5 Battles gespielt", icon: "bolt.fill", color: .blue))
        }
        if winStreak >= 3 {
            badges.append(ProfileBadge(title: "Streak", subtitle: "3 Wins in Folge", icon: "crown.fill", color: .purple))
        }

        return badges
    }

    private func badgeForCode(_ code: String) -> ProfileBadge? {
        switch code.lowercased() {
        case "first_win":
            return ProfileBadge(title: "Erster Sieg", subtitle: "1 Battle gewonnen", icon: "star.fill", color: .challengrYellow)
        case "win_streak_3":
            return ProfileBadge(title: "Streak", subtitle: "3 Wins in Folge", icon: "crown.fill", color: .purple)
        case "wins_3":
            return ProfileBadge(title: "Siegeszug", subtitle: "3 Siege", icon: "flame.fill", color: .challengrRed)
        case "battles_5":
            return ProfileBadge(title: "Aktiv", subtitle: "5 Battles gespielt", icon: "bolt.fill", color: .blue)
        default:
            return nil
        }
    }

    private var currentWinStreak: Int {
        let ordered = battleHistory
            .compactMap { battle -> (Date, Bool)? in
                guard let date = parseDate(battle.createdAt) else { return nil }
                return (date, battle.won)
            }
            .sorted { $0.0 > $1.0 }

        var streak = 0
        for (_, won) in ordered {
            if won {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date
        }

        let plainFormatter = DateFormatter()
        plainFormatter.dateFormat = "yyyy-MM-dd"
        return plainFormatter.date(from: String(value.prefix(10)))
    }

    private var legendView: some View {
        HStack(spacing: 12) {
            legendItem(icon: "book.closed", title: "Wissen", color: categoryColor(for: "Wissen"))
            legendItem(icon: "figure.run", title: "Fitness", color: categoryColor(for: "Fitness"))
            legendItem(icon: "flame", title: "Mutprobe", color: categoryColor(for: "Mutprobe"))
            legendItem(icon: "iphone", title: "iPhone", color: categoryColor(for: "iPhone"))
            legendItem(icon: "person.2", title: "Customer", color: categoryColor(for: "Customer"))
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.vertical, 4)
    }

    private func legendItem(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(valueColor)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(GameStyle.panelFill)
                .shadow(color: .black.opacity(0.08),
                        radius: 6, x: 0, y: 3)
        )
    }
}
