import SwiftUI

/// Eigene Emote-Kurzwahl auf der Karte (wie die Reaktionen bei WhatsApp), lokal gespeichert.
/// Einträge sind Emojis oder Sticker als "stk:<id>".
enum EmoteFavorites {
    static let key = "emoteFavorites"
    static let slots = 4

    static func load(defaults: UserDefaults = .standard) -> [String] {
        let saved = (defaults.stringArray(forKey: key) ?? []).filter { Emotes.all.contains($0) || Stickers.from(token: $0) != nil }
        return saved.count == slots ? saved : Emotes.map
    }

    static func save(_ list: [String], defaults: UserDefaults = .standard) {
        defaults.set(list, forKey: key)
    }

    /// Emoji/Sticker in die Kurzwahl: kommt nach vorne, das hinterste fällt raus. Schon drin → bleibt, wie es ist.
    static func adding(_ emoji: String, to list: [String]) -> [String] {
        guard !list.contains(emoji) else { return list }
        return Array(([emoji] + list).prefix(slots))
    }
}

/// Alle Emotes zum Schicken (Emojis oder Sticker); im Bearbeiten-Modus tauscht ein Tipp das Emote in die Kurzwahl.
struct EmotePickerSheet: View {
    @Binding var favorites: [String]
    let onSend: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var showStickers = false

    private let emojiColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)
    private let stickerColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

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
                ForEach(favorites, id: \.self) { token in
                    EmoteGlyph(token: token, emojiSize: 24, stickerSize: 48)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(editing ? 0.18 : 0.1)))
                        .accessibilityLabel(Emotes.spokenName(token))
                }
                Spacer()
            }
            if editing {
                Text("Tippe ein Emoji oder einen Sticker, um es in deine Kurzwahl auf der Karte zu holen.")
                    .font(.footnote)
                    .foregroundColor(GameStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            kindSwitch

            ScrollView(showsIndicators: false) {
                if showStickers {
                    LazyVGrid(columns: stickerColumns, spacing: 10) {
                        ForEach(Stickers.all) { sticker in
                            cell(sticker.token) {
                                StickerImage(sticker: sticker, size: 72)
                                    .frame(maxWidth: .infinity, minHeight: 80)
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: emojiColumns, spacing: 10) {
                        ForEach(Emotes.all, id: \.self) { emoji in
                            cell(emoji) {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(GameStyle.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Umschalter "Emojis | Sticker" im Spiel-Look
    private var kindSwitch: some View {
        HStack(spacing: 4) {
            ForEach([false, true], id: \.self) { stickers in
                let selected = showStickers == stickers
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showStickers = stickers }
                    SoundManager.shared.play(.click)
                } label: {
                    Text(stickers ? "STICKER" : "EMOJIS")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundColor(selected ? .challengrDark : .white.opacity(0.8))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(Capsule().fill(selected ? Color.challengrYellow : .clear))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(GameStyle.panelFill))
        .overlay(Capsule().stroke(GameStyle.panelStroke, lineWidth: 1))
    }

    private func cell<Content: View>(_ token: String, @ViewBuilder label: () -> Content) -> some View {
        let isFavorite = favorites.contains(token)
        return Button {
            if editing {
                favorites = EmoteFavorites.adding(token, to: favorites)
                EmoteFavorites.save(favorites)
                SoundManager.shared.play(.click)
            } else {
                onSend(token)
                dismiss()
            }
        } label: {
            label()
                .background(RoundedRectangle(cornerRadius: 14).fill(GameStyle.panelFill))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(editing && isFavorite ? Color.challengrYellow : GameStyle.panelStroke,
                                lineWidth: editing && isFavorite ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(editing ? "\(Emotes.spokenName(token)) zur Kurzwahl" : "\(Emotes.spokenName(token)) schicken")
    }
}
