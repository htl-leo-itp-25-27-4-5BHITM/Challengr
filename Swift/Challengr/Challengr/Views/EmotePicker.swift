import SwiftUI

/// Eigene Emote-Kurzwahl auf der Karte (wie die Reaktionen bei WhatsApp), lokal gespeichert.
enum EmoteFavorites {
    static let key = "emoteFavorites"
    static let slots = 4

    static func load(defaults: UserDefaults = .standard) -> [String] {
        let saved = (defaults.stringArray(forKey: key) ?? []).filter(Emotes.all.contains)
        return saved.count == slots ? saved : Emotes.map
    }

    static func save(_ list: [String], defaults: UserDefaults = .standard) {
        defaults.set(list, forKey: key)
    }

    /// Emoji in die Kurzwahl: kommt nach vorne, das hinterste fällt raus. Schon drin → bleibt, wie es ist.
    static func adding(_ emoji: String, to list: [String]) -> [String] {
        guard !list.contains(emoji) else { return list }
        return Array(([emoji] + list).prefix(slots))
    }
}

/// Alle Emotes zum Schicken; im Bearbeiten-Modus tauscht ein Tipp das Emoji in die Kurzwahl.
struct EmotePickerSheet: View {
    @Binding var favorites: [String]
    let onSend: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editing = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(editing ? "KURZWAHL WÄHLEN" : "EMOTE SCHICKEN")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(.white)
                Spacer()
                Button(editing ? "Fertig" : "Kurzwahl bearbeiten") {
                    withAnimation(.easeOut(duration: 0.15)) { editing.toggle() }
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.challengrYellow)
            }

            // Aktuelle Kurzwahl
            HStack(spacing: 8) {
                ForEach(favorites, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(editing ? 0.18 : 0.1)))
                }
                Spacer()
            }
            if editing {
                Text("Tippe ein Emoji, um es in deine Kurzwahl auf der Karte zu holen.")
                    .font(.footnote)
                    .foregroundColor(GameStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Emotes.all, id: \.self) { emoji in
                    let isFavorite = favorites.contains(emoji)
                    Button {
                        if editing {
                            favorites = EmoteFavorites.adding(emoji, to: favorites)
                            EmoteFavorites.save(favorites)
                            SoundManager.shared.play(.tap)
                        } else {
                            onSend(emoji)
                            dismiss()
                        }
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(GameStyle.panelFill))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(editing && isFavorite ? Color.challengrYellow : GameStyle.panelStroke,
                                            lineWidth: editing && isFavorite ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(editing ? "\(emoji) zur Kurzwahl" : "\(emoji) schicken")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(GameStyle.background.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
