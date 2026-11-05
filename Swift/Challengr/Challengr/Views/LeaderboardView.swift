import SwiftUI

/// Ranglisten: Top 10 aller Spieler und Freunde, darunter immer der eigene Platz.
struct LeaderboardView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case top = "Top 10"
        case friends = "Freunde"
        var id: String { rawValue }
    }

    /// Ringfarbe nach Rang (wie auf der Karte)
    var rankColor: (String) -> Color = { _ in .challengrYellow }

    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .top
    @State private var board: Leaderboard?
    @State private var failed = false

    private let service = LeaderboardService()

    var body: some View {
        ZStack {
            GameStyle.background.ignoresSafeArea()

            VStack(spacing: 14) {
                header
                tabPicker

                if let board {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(rows(of: board)) { row in
                                LeaderboardRowView(row: row, ringColor: rankColor(row.rankName))
                            }
                            if tab == .friends && board.friends.count <= 1 {
                                emptyFriends
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .refreshable { await load() }

                    // Eigener Platz – immer sichtbar, wenn man nicht schon in der Liste oben steht
                    if tab == .top, let me = board.me, !board.meIsInTop {
                        VStack(spacing: 6) {
                            Text("DEIN PLATZ VON \(board.totalPlayers)")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .tracking(1.2)
                                .foregroundColor(GameStyle.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            LeaderboardRowView(row: me, ringColor: rankColor(me.rankName))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                } else if failed {
                    Spacer()
                    VStack(spacing: 10) {
                        Text("Rangliste konnte nicht geladen werden.")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        GamePillButton(icon: "arrow.clockwise", title: "Nochmal") { Task { await load() } }
                    }
                    Spacer()
                } else {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
            }
            .padding(.top, 18)
        }
        .task { await load() }
    }

    private var header: some View {
        ZStack {
            Text("RANGLISTE")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .tracking(4)
                .foregroundColor(.challengrYellow)
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(GameStyle.panelFill))
                        .overlay(Circle().stroke(GameStyle.panelStroke, lineWidth: 1))
                }
                .accessibilityLabel("Schließen")
            }
        }
        .padding(.horizontal, 16)
    }

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { t in
                Button {
                    SoundManager.shared.play(.click)
                    withAnimation(.easeOut(duration: 0.2)) { tab = t }
                } label: {
                    Text(t.rawValue.uppercased())
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(tab == t ? .challengrDark : .white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(tab == t ? Color.challengrYellow : .clear))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == t ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(GameStyle.panelFill))
        .overlay(Capsule().stroke(GameStyle.panelStroke, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var emptyFriends: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.challengrYellow)
            Text("Füge Freunde hinzu und vergleicht eure Trophäen.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(GameStyle.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .gamePanel(padding: 16)
        .padding(.top, 6)
    }

    private func rows(of board: Leaderboard) -> [LeaderboardRow] {
        tab == .top ? board.school : board.friends
    }

    private func load() async {
        do {
            board = try await service.load()
            failed = false
        } catch {
            if board == nil { failed = true }
        }
    }
}

/// Eine Zeile: Platz (1–3 mit Medaille), Figur, Name, Rang, Trophäen. Die eigene Zeile ist gelb umrandet.
struct LeaderboardRowView: View {
    let row: LeaderboardRow
    var ringColor: Color = .challengrYellow

    private var medalColor: Color? {
        switch row.place {
        case 1: return .challengrYellow
        case 2: return Color(white: 0.78)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.25)
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let medalColor {
                    Circle().fill(medalColor).frame(width: 30, height: 30)
                }
                Text("\(row.place)")
                    .font(.system(size: row.place > 99 ? 12 : 15, weight: .black, design: .rounded))
                    .foregroundColor(medalColor == nil ? .white.opacity(0.8) : .challengrDark)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 34)

            CharacterBadge(character: GameCharacter.from(serverId: row.character) ?? .opponent,
                           ringColor: ringColor, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.me ? "\(row.name) (Du)" : row.name)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(row.rankName.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(ringColor)
            }
            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.challengrYellow)
                Text(row.trophies.formatted())
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
        }
        .gamePanel(padding: 10, cornerRadius: 16, highlight: row.me ? .challengrYellow : nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Platz \(row.place), \(row.name)\(row.me ? ", du" : ""), \(row.rankName), \(row.trophies) Trophäen")
    }
}
