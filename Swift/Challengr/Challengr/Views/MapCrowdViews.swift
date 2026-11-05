import SwiftUI

/// Viele Spieler auf einem Fleck: eine Figur mit Zahl – ein Tipp öffnet die Liste "Spieler hier".
struct MapCrowdPin: View {
    let front: GameCharacter
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MapCharacterPin(character: front, ringColor: .white, seed: "crowd")
                .overlay(alignment: .top) {
                    HStack(spacing: 3) {
                        Image(systemName: "person.3.fill").font(.system(size: 10, weight: .black))
                        Text("\(count)").font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.challengrDark)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.challengrYellow))
                    .overlay(Capsule().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) Spieler hier – tippen zum Auswählen")
    }
}

/// Liste der Spieler auf einem vollen Fleck; ein Tipp wählt einen aus (öffnet sein Popup auf der Karte).
struct MapCrowdSheet: View {
    struct Entry: Identifiable {
        let id: String
        let name: String
        let rankName: String
        let character: GameCharacter
        let ringColor: Color
        var isFriend = false
    }

    let entries: [Entry]
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GameSectionHeader(title: "Spieler hier", count: entries.count)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        Button {
                            dismiss()
                            onPick(entry.id)
                        } label: {
                            HStack(spacing: 12) {
                                CharacterBadge(character: entry.character, ringColor: entry.ringColor, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.system(size: 15, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(entry.rankName.uppercased())
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .tracking(1)
                                        .foregroundColor(entry.ringColor)
                                }
                                Spacer()
                                if entry.isFriend {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.challengrGreen)
                                        .accessibilityLabel("Freund")
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(GameStyle.secondaryText)
                            }
                            .gamePanel(padding: 10, cornerRadius: 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(GameStyle.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .environment(\.colorScheme, .dark)
    }
}
