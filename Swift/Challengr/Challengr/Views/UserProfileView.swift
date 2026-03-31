//
//  UserProfileView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 04.03.26.
//
import SwiftUI
import Charts

struct UserProfileData {
    let name: String
    let avatarImageName: String
    let rankName: String
    let dailyStreak: Int
    let totalChallenges: Int
    let wonChallenges: Int
    let points: Int
}

struct UserProfileView: View {
    let data: UserProfileData
    let pointsHistory: [PlayerPointsHistoryDTO]
    let battleHistory: [BattleHistoryDTO]

    @State private var selectedDate: String? = nil
    @State private var selectedPoints: Int? = nil
    @State private var isChartExpanded: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)

                Image(data.avatarImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.yellow, lineWidth: 4)
                    )
                    .shadow(radius: 10)

                Text(data.name)
                    .font(.system(size: 24, weight: .bold))

                Text("\(data.points) Punkte")
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        StatBox(title: "Tagesstreak",
                                value: "\(data.dailyStreak) 🔥")
                        StatBox(title: "Challenges",
                                value: "\(data.totalChallenges)")
                    }

                    HStack(spacing: 12) {
                        StatBox(title: "Gewonnen",
                                value: "\(data.wonChallenges)")
                        StatBox(title: "Rang",
                                value: data.rankName)
                    }
                }
                .padding(.top, 8)

                pointsChart

                battleDetailList(for: selectedDate)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var pointsChart: some View {
        let aggregatedHistory = startOfDayHistory(pointsHistory, battleHistory: battleHistory)
        let sortedHistory = aggregatedHistory.sorted { $0.date < $1.date }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Punkteverlauf")
                    .font(.system(size: 14, weight: .bold))
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
                Text("Noch keine Daten")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else if isChartExpanded {
                Chart(sortedHistory) { entry in
                    LineMark(
                        x: .value("Datum", entry.date),
                        y: .value("Punkte", entry.points)
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
                        y: .value("Punkte", entry.points)
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
                                            selectedPoints = sortedHistory.first { $0.date == date }?.points
                                        }
                                    }
                            )
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        if let selectedDate,
                           let selectedPoints,
                           let xPosition = proxy.position(forX: selectedDate),
                           let yPosition = proxy.position(forY: selectedPoints) {
                            let plotFrame = geometry[proxy.plotAreaFrame]
                            let point = CGPoint(x: xPosition + plotFrame.minX, y: yPosition + plotFrame.minY)

                            Circle()
                                .fill(Color.challengrYellow)
                                .frame(width: 10, height: 10)
                                .position(point)

                            VStack(spacing: 2) {
                                Text(selectedDate)
                                    .font(.caption2.weight(.semibold))
                                Text("\(selectedPoints) Punkte")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
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
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .padding(.top, 12)
    }

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
                            selectedPoints = nil
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
                            Text(battle.won ? "Gewonnen" : "Verloren")
                                .font(.caption)
                                .foregroundColor(battle.won ? .challengrGreen : .challengrRed)

                            Text("Δ \(battle.pointsDelta)")
                                .font(.caption)
                                .foregroundColor(deltaColor)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .padding(.top, 8)
    }

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

    private func startOfDayHistory(
        _ history: [PlayerPointsHistoryDTO],
        battleHistory: [BattleHistoryDTO]
    ) -> [PlayerPointsHistoryDTO] {
        let ordered = history.sorted { $0.date < $1.date }
        var endOfDayPoints: [String: Int] = [:]
        ordered.forEach { entry in
            endOfDayPoints[entry.date] = entry.points
        }

        let dailyDelta = Dictionary(grouping: battleHistory) { battle in
            String(battle.createdAt.prefix(10))
        }.mapValues { battles in
            battles.reduce(0) { $0 + $1.pointsDelta }
        }

        let dates = endOfDayPoints.keys.sorted()
        return dates.map { date in
            let endPoints = endOfDayPoints[date] ?? 0
            let delta = dailyDelta[date] ?? 0
            let startPoints = endPoints - delta
            return PlayerPointsHistoryDTO(date: date, points: startPoints)
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08),
                        radius: 6, x: 0, y: 3)
        )
    }
}
