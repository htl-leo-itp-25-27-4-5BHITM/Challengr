import SwiftUI

/// Sticker-Album: alle Sticker, gefundene bunt mit Anzahl, fehlende als Schatten.
struct StickerAlbumView: View {
    @ObservedObject private var collection = StickerCollection.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("STICKER-ALBUM")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(.white)
                Spacer()
                Text("\(collection.foundCount)/\(Stickers.all.count)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.challengrYellow)
                    .accessibilityLabel("\(collection.foundCount) von \(Stickers.all.count) gefunden")
            }
            Text("Sticker gibt's in Geschenken von Freunden. Jeder lässt sich einmal verschicken – also ruhig doppelt sammeln.")
                .font(.footnote)
                .foregroundColor(GameStyle.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Stickers.all) { sticker in
                        cell(sticker)
                    }
                }
            }
        }
        .padding(20)
        .background(GameStyle.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await collection.load() }
    }

    private func cell(_ sticker: Sticker) -> some View {
        let found = collection.hasFound(sticker.id)
        let count = collection.count(of: sticker.id)
        return VStack(spacing: 4) {
            StickerImage(sticker: sticker, size: 68)
                // Noch nicht gefunden: nur der Umriss
                .colorMultiply(found ? .white : .black)
                .opacity(found ? (count > 0 ? 1 : 0.45) : 0.35)
                .overlay {
                    if !found {
                        Text("?")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if found { StickerCountBadge(count: count) }
                }
            Text(found ? sticker.label : "???")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(found ? .white.opacity(0.85) : GameStyle.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14).fill(GameStyle.panelFill))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(found && Stickers.animatedIds.contains(sticker.id) ? Color.challengrYellow.opacity(0.7) : GameStyle.panelStroke,
                        lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(found ? "Sticker: \(sticker.label), \(count) Stück" : "Noch nicht gefunden")
    }
}

/// Kleine Anzahl-Marke ("×3") an einem Sticker
struct StickerCountBadge: View {
    let count: Int

    var body: some View {
        Text("×\(count)")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(count > 0 ? .challengrDark : .white.opacity(0.8))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(count > 0 ? Color.challengrYellow : Color.white.opacity(0.2)))
            .offset(x: 4, y: -4)
            .accessibilityHidden(true)
    }
}
