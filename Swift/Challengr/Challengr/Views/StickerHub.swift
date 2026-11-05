import SwiftUI

/// Alles rund um Sticker an einem Ort (Menü → Sticker): Geschenke öffnen, Album mit Belohnungen,
/// woher man Sticker bekommt und das Sticker-Paket. Ein Tipp auf einen Sticker zeigt ihn groß –
/// dort kommt er in die Kurzwahl oder geht als Geschenk an einen Freund.
struct StickerHubView: View {
    /// nil = ohne Geschenke und Verschenken (z. B. Vorschau)
    let ownPlayerId: String?
    @Binding var favorites: [String]

    @ObservedObject private var collection = StickerCollection.shared
    @StateObject private var friends = FriendsViewModel()
    @State private var selected: Sticker? = nil
    @State private var openedGift: OpenedGiftPresentation? = nil
    @State private var reward: StickerReward? = nil
    @State private var claimingStage: Int? = nil
    @State private var toast: String? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !friends.incomingGifts.isEmpty { giftsSection }
                if !collection.stages.isEmpty { stagesSection }
                albumSection
                sourcesSection
            }
            .padding(20)
        }
        .background(GameStyle.background.ignoresSafeArea())
        .overlay(alignment: .bottom) { StickerToast(text: toast) }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await collection.load()
            if let ownPlayerId { await friends.loadAll(ownPlayerId: ownPlayerId, coordinate: nil, radiusMeters: 0) }
        }
        .sheet(item: $selected) { sticker in
            StickerDetailSheet(sticker: sticker, ownPlayerId: ownPlayerId, favorites: $favorites, friends: friends)
        }
        .sheet(item: $openedGift) { gift in
            GiftOpenedSheet(senderName: gift.senderName, sticker: gift.sticker, chosen: gift.chosen)
                .presentationDetents([.height(gift.sticker == nil ? 300 : 440)])
        }
        .sheet(item: $reward) { StickerRewardSheet(reward: $0) }
    }

    // MARK: - Kopf

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("STICKER")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("\(collection.foundCount) von \(Stickers.all.count) gefunden · \(collection.sendableCount) zum Schicken")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(GameStyle.secondaryText)
            }
            Spacer()
            if let coins = collection.coins { CoinChip(coins: coins) }
        }
    }

    // MARK: - Geschenke

    private var giftsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GameSectionHeader(title: "Geschenke", count: friends.incomingGifts.count)
            ForEach(friends.incomingGifts) { gift in
                GiftInboxRow(senderName: senderName(of: gift)) { open(gift) }
            }
        }
    }

    private func senderName(of gift: FriendGiftDTO) -> String {
        friends.friends.first(where: { $0.id == gift.fromPlayerId })?.name ?? "Ein Freund"
    }

    private func open(_ gift: FriendGiftDTO) {
        guard let ownPlayerId else { return }
        let name = senderName(of: gift)
        Task {
            if let opened = await friends.claimGift(giftId: gift.id, ownPlayerId: ownPlayerId) {
                openedGift = OpenedGiftPresentation(senderName: name, sticker: opened.sticker, chosen: opened.chosen)
            } else {
                show(friends.errorText)
            }
        }
    }

    // MARK: - Album-Belohnungen

    private var stagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GameSectionHeader(title: "Album-Belohnungen")
            AlbumProgressBar(found: collection.foundCount, total: Stickers.all.count)
            HStack(spacing: 8) {
                ForEach(collection.stages) { stageTile($0) }
            }
        }
    }

    private func stageTile(_ stage: StickerCollection.Stage) -> some View {
        let canClaim = !stage.claimed && collection.foundCount >= stage.found
        return Button { claim(stage) } label: {
            VStack(spacing: 5) {
                if stage.goldFrame {
                    Circle().stroke(GoldFrame.gradient, lineWidth: 5).frame(width: 24, height: 24)
                } else {
                    Image("MenuCoin").resizable().scaledToFit().frame(width: 26, height: 26)
                }
                Text(stage.goldFrame ? "RAHMEN" : "+\(stage.coins)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                Text(stage.claimed ? "ABGEHOLT" : canClaim ? "ABHOLEN" : "\(stage.found) STICKER")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.6)
                    .opacity(0.8)
            }
            .foregroundColor(canClaim ? .challengrDark : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(canClaim ? Color.challengrYellow : GameStyle.panelFill))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameStyle.panelStroke, lineWidth: 1))
            .opacity(stage.claimed ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!canClaim || claimingStage != nil)
        .accessibilityLabel(stage.goldFrame
                            ? "Goldener Rahmen bei vollem Album\(stage.claimed ? ", abgeholt" : canClaim ? ", abholen" : "")"
                            : "\(stage.coins) Coins ab \(stage.found) Stickern\(stage.claimed ? ", abgeholt" : canClaim ? ", abholen" : "")")
    }

    private func claim(_ stage: StickerCollection.Stage) {
        claimingStage = stage.found
        Task {
            defer { claimingStage = nil }
            do {
                try await collection.claimStage(stage)
                SoundManager.shared.play(.win)
                show(stage.goldFrame ? "Goldener Rahmen freigeschaltet – alle sehen ihn auf der Karte!"
                                     : "+\(stage.coins) Coins fürs Album")
            } catch {
                show("Abholen ging gerade nicht – versuch's gleich nochmal.")
            }
        }
    }

    // MARK: - Album

    private var albumSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GameSectionHeader(title: "Album")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Stickers.all) { cell($0) }
            }
            Text("Tipp auf einen Sticker: groß ansehen, in die Kurzwahl holen oder einem Freund schenken.")
                .font(.footnote)
                .foregroundColor(GameStyle.secondaryText)
        }
    }

    private func cell(_ sticker: Sticker) -> some View {
        let found = collection.hasFound(sticker.id)
        let count = collection.count(of: sticker.id)
        return Button { selected = sticker } label: {
            VStack(spacing: 4) {
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
        }
        .buttonStyle(.plain)
        .disabled(!found)
        .accessibilityLabel(found ? "Sticker: \(sticker.label), \(count) Stück" : "Noch nicht gefunden")
    }

    // MARK: - Woher Sticker kommen

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GameSectionHeader(title: "So bekommst du Sticker")
            sourceRow(icon: "gift.fill", color: .challengrRed, title: "Geschenke von Freunden",
                      detail: "Jeder Freund kann dir eins pro Tag schicken (Profil → Freunde → Geschenk).")
            sourceRow(icon: "trophy.fill", color: .orange, title: "Liga-Siege",
                      detail: "Nach einem Sieg springt manchmal ein Sticker raus.")
            sourceRow(icon: "hand.wave.fill", color: .challengrGreen, title: "Tagesaufgabe „Schau vorbei“",
                      detail: "Jeden Tag ein Sticker – im Menü unter Aufgaben.")
            StickerPackOffer(onBought: { stickers in
                reward = StickerReward.pack(stickers)
            }, onError: show)
        }
    }

    private func sourceRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(color))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GameStyle.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .gamePanel(padding: 12, cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }

    private func show(_ text: String?) {
        guard let text else { return }
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { if toast == text { toast = nil } }
        }
    }
}

/// Fortschritt im Album mit Markierungen für die Belohnungen
struct AlbumProgressBar: View {
    let found: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(found >= total ? AnyShapeStyle(GoldFrame.gradient) : AnyShapeStyle(Color.challengrYellow))
                    .frame(width: geo.size.width * CGFloat(min(found, total)) / CGFloat(max(total, 1)))
            }
        }
        .frame(height: 10)
        .accessibilityLabel("\(found) von \(total) Stickern gefunden")
    }
}

/// Coins wie in den Aufgaben
struct CoinChip: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 5) {
            Image("MenuCoin").resizable().scaledToFit().frame(width: 18, height: 18)
            Text(coins.formatted())
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText(value: Double(coins)))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(GameStyle.panelFill))
        .accessibilityLabel("\(coins) Challengr Coins")
    }
}

// MARK: - Sticker groß

/// Ein Sticker groß: Anzahl, in die Kurzwahl holen, einem Freund schenken (wem er noch fehlt, steht dabei).
struct StickerDetailSheet: View {
    let sticker: Sticker
    let ownPlayerId: String?
    @Binding var favorites: [String]
    @ObservedObject var friends: FriendsViewModel

    @ObservedObject private var collection = StickerCollection.shared
    @State private var gifting = false
    @State private var missing: Set<String> = []
    @State private var sendingTo: String? = nil
    /// Beim Schenken ganz hochfahren, damit die Freundesliste Platz hat
    @State private var detent: PresentationDetent = .medium

    private var count: Int { collection.count(of: sticker.id) }
    private var inFavorites: Bool { favorites.contains(sticker.token) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                StickerImage(sticker: sticker, size: 180, animated: true)
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                    .padding(.top, 24)
                Text(sticker.label.uppercased())
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                if Stickers.animatedIds.contains(sticker.id) { RareTag() }
                Text(count > 0 ? "Du hast ihn \(count)× – jedes Verschicken oder Schenken braucht einen."
                               : "Gerade keiner übrig. Neue gibt's über Geschenke, Siege, die Tagesaufgabe und den Shop.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GameStyle.secondaryText)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button {
                        favorites = EmoteFavorites.adding(sticker.token, to: favorites)
                        EmoteFavorites.save(favorites)
                        SoundManager.shared.play(.click)
                    } label: {
                        Label(inFavorites ? "IN DER KURZWAHL" : "IN KURZWAHL", systemImage: inFavorites ? "checkmark" : "star.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StickerActionStyle(filled: false))
                    .disabled(inFavorites)

                    if ownPlayerId != nil {
                        Button {
                            withAnimation { gifting.toggle() }
                            if gifting { detent = .large }
                        } label: {
                            Label("FREUND SCHENKEN", systemImage: "gift.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StickerActionStyle(filled: true))
                        .disabled(count == 0)
                    }
                }

                if gifting && count > 0 { friendPicker }

                if let info = friends.infoText {
                    Text(info).font(.footnote.bold()).foregroundColor(.challengrGreen)
                }
                if let error = friends.errorText {
                    Text(error).font(.footnote.bold()).foregroundColor(.challengrRed)
                }
            }
            .padding(20)
        }
        .background(GameStyle.background.ignoresSafeArea())
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .task(id: gifting) {
            if gifting { missing = await collection.friendsMissing(sticker) }
        }
        .onAppear {
            friends.infoText = nil
            friends.errorText = nil
        }
    }

    /// Freunde, denen er fehlt, stehen oben
    private var friendPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            if friends.friends.isEmpty {
                Text("Noch keine Freunde – füge welche über Profil → Freunde hinzu.")
                    .font(.footnote)
                    .foregroundColor(GameStyle.secondaryText)
            }
            ForEach(friends.friends.sorted { missing.contains($0.id) && !missing.contains($1.id) }) { friend in
                HStack(spacing: 10) {
                    CharacterBadge(character: GameCharacter.from(serverId: friend.character) ?? .opponent,
                                   ringColor: .white.opacity(0.5), size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.name)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(missing.contains(friend.id) ? "FEHLT NOCH IM ALBUM" : "hat ihn schon")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(missing.contains(friend.id) ? .challengrYellow : GameStyle.secondaryText)
                    }
                    Spacer()
                    GamePillButton(icon: "gift.fill", title: sendingTo == friend.id ? "…" : "Schenken",
                                   color: .challengrRed, textColor: .white) {
                        send(to: friend)
                    }
                    .disabled(sendingTo != nil || count == 0)
                }
                .gamePanel(padding: 10, cornerRadius: 16)
            }
        }
        .transition(.opacity)
    }

    private func send(to friend: PlayerDTO) {
        guard let ownPlayerId else { return }
        sendingTo = friend.id
        Task {
            defer { sendingTo = nil }
            if await friends.sendSticker(sticker, ownPlayerId: ownPlayerId, to: friend.id, name: friend.name) {
                missing.remove(friend.id)
                if count == 0 { withAnimation { gifting = false } }
            }
        }
    }
}

private struct StickerActionStyle: ButtonStyle {
    let filled: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundColor(filled ? .challengrDark : .white)
            .padding(.vertical, 12)
            .background(Capsule().fill(filled ? Color.challengrYellow : GameStyle.panelFill))
            .overlay(Capsule().stroke(filled ? .clear : GameStyle.panelStroke, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
    }
}

/// "SELTEN · BEWEGT SICH"
struct RareTag: View {
    var body: some View {
        Text("SELTEN · BEWEGT SICH")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .tracking(1.2)
            .foregroundColor(.challengrDark)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(Color.challengrYellow))
    }
}

// MARK: - Sticker-Paket

/// Sticker-Paket für Coins (im Sticker-Bereich und im Shop)
struct StickerPackOffer: View {
    var onBought: ([Sticker]) -> Void
    var onError: (String) -> Void

    @ObservedObject private var collection = StickerCollection.shared
    @State private var buying = false

    var body: some View {
        HStack(spacing: 12) {
            // drei Sticker aufgefächert
            ZStack {
                ForEach(0..<3) { i in
                    StickerImage(sticker: Stickers.all[[13, 0, 4][i]], size: 40)
                        .rotationEffect(.degrees(Double(i - 1) * 14))
                        .offset(x: CGFloat(i - 1) * 11)
                }
            }
            .frame(width: 64, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sticker-Paket")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("\(StickerCollection.packSize) zufällige Sticker für deine Coins")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GameStyle.secondaryText)
            }
            Spacer(minLength: 4)
            Button(action: buy) {
                HStack(spacing: 4) {
                    if buying {
                        ProgressView().tint(.challengrDark)
                    } else {
                        Image("MenuCoin").resizable().scaledToFit().frame(width: 16, height: 16)
                        Text("\(collection.packPrice)")
                    }
                }
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.challengrDark)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Capsule().fill(Color.challengrYellow))
            }
            .buttonStyle(.plain)
            .disabled(buying)
            .accessibilityLabel("Sticker-Paket für \(collection.packPrice) Coins kaufen")
        }
        .gamePanel(padding: 12, cornerRadius: 16, highlight: .challengrYellow)
    }

    private func buy() {
        if let coins = collection.coins, coins < collection.packPrice {
            onError(StickerCollection.PackError.notEnoughCoins.errorDescription ?? "")
            return
        }
        buying = true
        Task {
            defer { buying = false }
            do {
                let stickers = try await collection.buyPack()
                SoundManager.shared.play(.giftClaimed)
                onBought(stickers)
            } catch {
                onError((error as? LocalizedError)?.errorDescription ?? "Kaufen ging gerade nicht.")
            }
        }
    }
}

// MARK: - Neue Sticker zeigen

/// Neue Sticker (Paket, Tagesaufgabe) groß zeigen
struct StickerReward: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let stickers: [Sticker]

    static func pack(_ stickers: [Sticker]) -> StickerReward {
        StickerReward(title: "STICKER-PAKET", subtitle: stickers.map(\.label).joined(separator: " · "), stickers: stickers)
    }

    static func single(_ sticker: Sticker, from source: String) -> StickerReward {
        StickerReward(title: "STICKER „\(sticker.label.uppercased())“", subtitle: source, stickers: [sticker])
    }
}

struct StickerRewardSheet: View {
    let reward: StickerReward

    @Environment(\.dismiss) private var dismiss
    @State private var shown = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: -18) {
                ForEach(Array(reward.stickers.enumerated()), id: \.offset) { i, sticker in
                    StickerImage(sticker: sticker, size: reward.stickers.count == 1 ? 170 : 120, animated: true)
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                        .rotationEffect(.degrees(reward.stickers.count == 1 ? 0 : Double(i - 1) * 8))
                        .scaleEffect(shown ? 1 : 0.2)
                        .opacity(shown ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.2 + Double(i) * 0.18), value: shown)
                }
            }
            .frame(height: 180)
            .padding(.top, 24)

            Text(reward.title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            if reward.stickers.contains(where: { Stickers.animatedIds.contains($0.id) }) { RareTag() }
            Text(reward.subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GameStyle.secondaryText)
                .multilineTextAlignment(.center)

            Button("Weiter") { dismiss() }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.challengrDark)
                .padding(.horizontal, 36)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.challengrYellow))
                .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(GameStyle.background.ignoresSafeArea())
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.visible)
        .onAppear { shown = true }
    }
}

// MARK: - Geschenke

struct OpenedGiftPresentation: Identifiable {
    let id = UUID()
    let senderName: String
    let sticker: Sticker?
    var chosen = false
}

struct GiftInboxRow: View {
    let senderName: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.challengrRed))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Geschenk erhalten")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Von \(senderName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GameStyle.secondaryText)
                }

                Spacer()

                Text("ÖFFNEN")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.challengrDark)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(Color.challengrYellow))
            }
            .padding(14)
            .background(GameStyle.panelFill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.challengrRed.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Geschenk von \(senderName) öffnen")
    }
}

struct GiftOpenedSheet: View {
    let senderName: String
    let sticker: Sticker?
    /// Vom Absender ausgesucht statt Zufall
    var chosen = false

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var collection = StickerCollection.shared
    @State private var opened = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Erst wackelt das Geschenk, dann ploppt der Sticker heraus
                Image(systemName: "gift.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(.challengrRed)
                    .rotationEffect(.degrees(opened ? 0 : -10))
                    .scaleEffect(opened && sticker != nil ? 0.2 : 1)
                    .opacity(opened && sticker != nil ? 0 : 1)
                if let sticker {
                    StickerImage(sticker: sticker, size: 170, animated: true)
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                        .scaleEffect(opened ? 1 : 0.2)
                        .opacity(opened ? 1 : 0)
                }
            }
            .frame(height: sticker == nil ? 90 : 180)
            .padding(.top, 24)

            Text(sticker.map { "STICKER „\($0.label.uppercased())“" } ?? "GESCHENK ERHALTEN")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if let sticker {
                if Stickers.animatedIds.contains(sticker.id) { RareTag() }
                Text("\(chosen ? "Von \(senderName) – extra für dich ausgesucht." : "Von \(senderName).") Du hast ihn jetzt \(collection.count(of: sticker.id))× – jedes Verschicken braucht einen.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GameStyle.secondaryText)
                    .multilineTextAlignment(.center)
            } else {
                Text("\(senderName) hat dir ein Geschenk geschickt.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(GameStyle.secondaryText)
            }

            Button("Weiter") { dismiss() }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.challengrDark)
                .padding(.horizontal, 36)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.challengrYellow))
                .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(GameStyle.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.35)) { opened = true }
        }
    }
}

// MARK: - Kleinteile

/// Goldener Rahmen fürs volle Album (Ring auf der Karte, am Profil-Knopf)
enum GoldFrame {
    static let gradient = AngularGradient(colors: [
        Color(red: 1.0, green: 0.88, blue: 0.4), Color(red: 0.82, green: 0.55, blue: 0.08),
        Color(red: 1.0, green: 0.96, blue: 0.68), Color(red: 0.78, green: 0.5, blue: 0.05),
        Color(red: 1.0, green: 0.88, blue: 0.4)
    ], center: .center)
}

/// Großer Sticker-Knopf auf der Karte: zeigt, wie viele man schicken kann, und öffnet die Sticker-Auswahl
struct StickerSendButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                StickerImage(sticker: Stickers.all[0], size: 30)
                Text("STICKER")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(1)
                Text("\(count)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(count > 0 ? Color.challengrYellow : Color.black.opacity(0.12)))
            }
            .foregroundColor(.challengrBlack)
            .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.9)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sticker schicken, \(count) übrig")
    }
}

/// Kurze Meldung unten im Sticker-Bereich
struct StickerToast: View {
    let text: String?

    var body: some View {
        if let text {
            Text(text)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.challengrDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Capsule().fill(Color.challengrYellow))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                .padding(.horizontal, 20).padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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
