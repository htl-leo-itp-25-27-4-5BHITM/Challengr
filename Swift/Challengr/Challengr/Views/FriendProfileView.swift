import SwiftUI

/// Öffentliches Profil eines Freundes: Figur, Rang, Trophäen und Statistik – im dunklen Spiel-Look.
struct FriendProfileView: View {
    let friend: PlayerDTO
    @Environment(\.dismiss) private var dismiss

    @State private var stats: PlayerStatsDTO?
    @State private var rank: TrophyRank?

    private let playerService = PlayerLocationService()
    private let rankService = RankService()

    private var character: GameCharacter { GameCharacter.from(serverId: friend.character) ?? .opponent }
    private var rankColor: Color { rank?.uiColor ?? .gray }

    private var winRateText: String {
        guard let stats, stats.totalChallenges > 0 else { return "–" }
        return "\(Int((Double(stats.wonChallenges) / Double(stats.totalChallenges) * 100).rounded()))%"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Eigene Knöpfe im Spiel-Look statt blauem Zurück-Pfeil und grauem Standard-Menü
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(GameStyle.panelFill))
                            .overlay(Circle().stroke(GameStyle.panelStroke, lineWidth: 1))
                    }
                    .accessibilityLabel("Zurück")
                    Spacer()
                    PlayerSafetyMenu(playerId: friend.id, playerName: friend.name, onBlocked: { dismiss() }, gameStyle: true)
                }

                hero

                HStack(spacing: 10) {
                    GameStatTile(icon: "trophy.fill", value: "\(friend.trophies ?? 0)", title: "Trophäen", color: .challengrYellow)
                    GameStatTile(icon: "flag.checkered", value: stats.map { "\($0.totalChallenges)" } ?? "–", title: "Battles", color: .white)
                    GameStatTile(icon: "star.fill", value: stats.map { "\($0.wonChallenges)" } ?? "–", title: "Siege", color: .orange)
                    GameStatTile(icon: "percent", value: winRateText, title: "Siegquote", color: .challengrGreen)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(GameStyle.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    /// Figur auf einer Bühne in Rangfarbe, darunter Name und Rang.
    private var hero: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(RadialGradient(colors: [rankColor.opacity(0.55), Color.challengrDark.opacity(0.9)],
                                     center: .top, startRadius: 10, endRadius: 300))
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(rankColor.opacity(0.6), lineWidth: 2)

            VStack(spacing: 8) {
                Image(character.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 190)
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
                    .accessibilityLabel(character.displayName)

                Text(friend.name.uppercased())
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 8) {
                    Text(friend.rankName.uppercased())
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.challengrDark)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(rankColor))
                    Label("\(friend.trophies ?? 0)", systemImage: "trophy.fill")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.challengrYellow)
                        .accessibilityLabel("\(friend.trophies ?? 0) Trophäen")
                }
                Text(character.displayName + " · " + character.tagline)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(GameStyle.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(height: 330)
    }

    private func load() async {
        async let statsAsync = try? playerService.loadPlayerStats(id: friend.id)
        async let ranksAsync = try? rankService.loadRanks()
        stats = await statsAsync
        rank = (await ranksAsync)?.first { $0.name == friend.rankName }
    }
}
