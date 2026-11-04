import SwiftUI
import ImageIO

// Kleine Animationen, damit die Karte lebendig wirkt (alles rein lokal, kein Backend nötig).
// Bei "Bewegung reduzieren" bleiben die Pins ruhig.

/// Spieler als Figur auf der (gekippten) Karte: Animation aus dem 3D-Modell, darunter
/// Schatten und ein Bodenring in Rang-Farbe. Beim eigenen Spieler laufen Radar-Wellen über den Boden.
struct MapCharacterPin: View {
    let character: GameCharacter
    let ringColor: Color
    var sonar = false
    var seed: String = ""
    var height: CGFloat = 78

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mapCrowded) private var crowded
    @Environment(\.mapNight) private var night

    var body: some View {
        TimelineView(.animation(minimumInterval: MapCrowd.spriteInterval(crowded: crowded, sonar: sonar), paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .bottom) {
                // Boden: Wellen, Schatten, Ring – flach gedrückt, damit sie auf der Karte "liegen"
                if sonar && !reduceMotion {
                    ForEach(0..<2, id: \.self) { i in
                        let p = MapVibe.ripplePhase(time: t, offset: Double(i) * 0.5)
                        Ellipse()
                            .stroke(ringColor.opacity(0.8 * (1 - p)), lineWidth: 3)
                            .frame(width: 50 + 90 * p, height: (50 + 90 * p) * MapVibe.groundRatio)
                            .offset(y: (50 + 90 * p) * MapVibe.groundRatio / 2 - 12)
                    }
                }
                Ellipse()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 42, height: 42 * MapVibe.groundRatio)
                    .blur(radius: 2)
                Ellipse()
                    .stroke(ringColor, lineWidth: 3)
                    .frame(width: 54, height: 54 * MapVibe.groundRatio)
                    // nachts leuchtet der Ring
                    .shadow(color: night ? ringColor.opacity(0.9) : .clear, radius: night ? 8 : 0)

                if let frame = MapSprites.frame(of: character,
                                                at: reduceMotion ? 0 : MapVibe.spriteFrame(time: t, seed: seed)) {
                    Image(uiImage: frame)
                        .resizable()
                        .scaledToFit()
                        // Gleicher Maßstab für alle: höhere Sheets (Merlos Hut) werden größer, nicht gestaucht
                        .frame(height: height * MapSprites.heightFactor(of: frame))
                        .offset(y: -7)
                }
            }
            // Platz nach oben, damit nichts abgeschnitten wird (Hüte, Schwerter)
            .frame(width: height * 1.6, height: height * MapSprites.maxHeightFactor + 12, alignment: .bottom)
        }
        .accessibilityElement()
        .accessibilityLabel(character.displayName)
    }
}

/// Zerlegt die Sprite-Sheets einmal in Einzelbilder.
enum MapSprites {
    private static var cache: [GameCharacter: [UIImage]] = [:]

    static func frames(of character: GameCharacter) -> [UIImage] {
        if let cached = cache[character] { return cached }
        guard let sheet = UIImage(named: character.mapSheetName)?.cgImage else { return [] }
        let count = GameCharacter.mapSheetFrames
        let w = sheet.width / count
        let frames = (0..<count).compactMap { i in
            sheet.cropping(to: CGRect(x: i * w, y: 0, width: w, height: sheet.height)).map { UIImage(cgImage: $0) }
        }
        cache[character] = frames
        return frames
    }

    /// Pixel-Höhe der meisten Sheets – entspricht `MapCharacterPin.height`.
    static let referenceHeight: CGFloat = 217
    /// Höchstes Sheet (Merlo, 265 px) im Verhältnis zur Referenz.
    static let maxHeightFactor: CGFloat = 265 / referenceHeight

    static func heightFactor(of frame: UIImage) -> CGFloat {
        Swift.max(1, frame.size.height * frame.scale / referenceHeight)
    }

    static func frame(of character: GameCharacter, at index: Int) -> UIImage? {
        let all = frames(of: character)
        return all.isEmpty ? nil : all[index % all.count]
    }
}

/// Wer auf der Karte angezeigt wird. Leer = alle Spieler in der Nähe (TestFlight/Live).
/// Für eine Demo mit nur bestimmten Konten hier Namen eintragen.
enum MapPlayerFilter {
    static var allowedNames: [String] = []

    static func isVisible(name: String) -> Bool {
        guard !allowedNames.isEmpty else { return true }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allowedNames.contains { $0.lowercased() == n }
    }
}

/// Pin eines anderen Spielers: wippt leicht im eigenen Takt, ploppt beim Erscheinen auf
/// und zeigt ab und zu eine Emoji-Blase oder einen Sticker.
struct LivelyPin<Content: View>: View {
    let seed: String
    var bubble: EmoteEvent? = nil
    /// Figuren-Pins bewegen sich schon selbst
    var bobs = true
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        Group {
            if bobs && !reduceMotion {
                // Nur wippende Pins brauchen eine eigene Animationsschleife
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    pin(bob: MapVibe.bobOffset(time: context.date.timeIntervalSinceReferenceDate, seed: seed))
                }
            } else {
                pin(bob: 0)
            }
        }
        .scaleEffect(appeared || reduceMotion ? 1 : 0.2)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { appeared = true }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: bubble)
    }

    private func pin(bob: Double) -> some View {
        content
            .offset(y: bob)
            .overlay(alignment: .top) {
                if let bubble {
                    Group {
                        if let sticker = bubble.sticker {
                            // groß genug zum Lesen; wächst nach oben, Unterkante wie bei der Emoji-Blase
                            StickerImage(sticker: sticker, size: 84, animated: true)
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                                .frame(height: 30, alignment: .bottom)
                        } else {
                            Text(bubble.emoji)
                                .font(.system(size: 18))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.white))
                                .overlay(Capsule().stroke(Color.challengrBlack.opacity(0.15), lineWidth: 1))
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                        }
                    }
                    .id(bubble.id)
                    .offset(y: (bobs ? -40 : -24) + bob)
                    .transition(.scale(scale: 0.3, anchor: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                }
            }
    }
}

/// Viele Spieler auf einem Fleck (z. B. Schulhof): ab hier laufen die Figuren-Animationen langsamer.
enum MapCrowd {
    static let threshold = 12

    /// Bilder pro Sekunde der Figuren-Animation: normal 15, bei Gedränge 6; der eigene Pin (Sonar) bleibt flüssig.
    static func spriteInterval(crowded: Bool, sonar: Bool) -> Double {
        crowded && !sonar ? 1.0 / 6 : 1.0 / 15
    }
}

private struct MapCrowdedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var mapCrowded: Bool {
        get { self[MapCrowdedKey.self] }
        set { self[MapCrowdedKey.self] = newValue }
    }
}

/// Reine Rechenlogik der Karten-Effekte (testbar).
enum MapVibe {
    /// Höhe:Breite eines Kreises auf dem Boden – passt zur gekippten Karte (55°), vorher zu flach.
    static let groundRatio: CGFloat = 0.5

    /// 0…1, eine Welle alle 2 Sekunden; `offset` verschiebt die zweite Welle.
    static func ripplePhase(time: TimeInterval, offset: Double = 0, period: Double = 2) -> Double {
        let x = (time / period + offset).truncatingRemainder(dividingBy: 1)
        return x < 0 ? x + 1 : x
    }

    /// Leichtes Auf und Ab (±3 pt), jeder Spieler mit eigener Phase.
    static func bobOffset(time: TimeInterval, seed: String) -> CGFloat {
        let phase = Double(stableHash(seed) % 628) / 100
        return CGFloat(sin(time * 2.2 + phase) * 3)
    }

    /// Aktuelles Bild der Figuren-Animation (12 Bilder/s, jeder Spieler leicht versetzt).
    static func spriteFrame(time: TimeInterval, seed: String, fps: Double = 12,
                            frames: Int = GameCharacter.mapSheetFrames) -> Int {
        let offset = stableHash(seed) % frames
        return (Int(time * fps) + offset) % frames
    }

    /// Spieler, die neu im Radius sind (nicht beim allerersten Laden).
    static func newArrivals(previous: [String]?, current: [String]) -> [String] {
        guard let previous else { return [] }
        let known = Set(previous)
        return current.filter { !known.contains($0) }
    }

    /// Stabiler Hash (Swift's hashValue ändert sich bei jedem App-Start).
    static func stableHash(_ s: String) -> Int {
        var h: UInt64 = 5381
        for b in s.utf8 { h = (h &* 33) &+ UInt64(b) }
        return Int(h % UInt64(Int.max))
    }
}

// MARK: - Emotes

/// Emotes, die man schicken kann (muss zur Liste im Backend passen: GameSocket.EMOTES).
enum Emotes {
    static let all = ["🔥", "😤", "💪", "👀", "🏆", "😂", "👋", "🥊", "😎", "🤝", "👏", "🙌", "😅", "🤔", "😱", "🥳", "🎉", "⚡", "🧠", "🏃", "👑", "🤯", "😴", "🙏"]
    /// Leiste im Battle (passt in eine Zeile)
    static let battle = Array(all.prefix(8))
    /// Standard-Kurzwahl für die Karte (Begrüßen/Necken); jeder kann sie selbst ändern (EmoteFavorites).
    static let map = ["👋", "🔥", "😤", "💪"]
    /// Wie lange eine Emote-Blase sichtbar bleibt.
    static let visibleSeconds: Double = 2.5

    /// Für VoiceOver: "🔥" bzw. "Sticker: Oida"
    static func spokenName(_ token: String) -> String {
        Stickers.from(token: token).map { "Sticker: \($0.label)" } ?? token
    }
}

/// Sticker mit Figuren aus dem Fight-Video (Bilder im Asset-Katalog unter "Sticker").
struct Sticker: Hashable, Identifiable {
    let id: String
    let label: String
    /// Was alte App-Versionen statt des Stickers zeigen (setzt der Server)
    let fallbackEmoji: String

    var assetName: String { "Sticker_\(id)" }
    /// So steht der Sticker in der Kurzwahl neben den Emojis
    var token: String { Stickers.tokenPrefix + id }

    /// Bewegte Fassung (animiertes WebP, Data-Asset "StickerAnim_<id>") – nur für einige Sticker
    var animationData: Data? {
        guard Stickers.animatedIds.contains(id) else { return nil }
        if let cached = Stickers.animationCache[id] { return cached }
        let data = NSDataAsset(name: "StickerAnim_\(id)")?.data
        Stickers.animationCache[id] = data
        return data
    }
}

/// Sticker, die man schicken kann (muss zur Liste im Backend passen: StickerCatalog.FALLBACK).
enum Stickers {
    static let all: [Sticker] = [
        Sticker(id: "aura", label: "+1000 Aura", fallbackEmoji: "🔥"),
        Sticker(id: "gogogo", label: "Gogogo", fallbackEmoji: "⚡"),
        Sticker(id: "1hit", label: "1 Hit", fallbackEmoji: "🥊"),
        Sticker(id: "locked", label: "Locked in", fallbackEmoji: "😤"),
        Sticker(id: "mvp", label: "MVP", fallbackEmoji: "🏆"),
        Sticker(id: "schularbeit", label: "Nach der Schularbeit", fallbackEmoji: "😴"),
        Sticker(id: "vorbei", label: "Noch nicht vorbei", fallbackEmoji: "💪"),
        Sticker(id: "farming", label: "Aura Farming", fallbackEmoji: "😎"),
        Sticker(id: "skillissue", label: "Skill Issue", fallbackEmoji: "😂"),
        Sticker(id: "oida", label: "Oida", fallbackEmoji: "😤"),
        Sticker(id: "minusaura", label: "-1000 Aura", fallbackEmoji: "😅"),
        Sticker(id: "brodachte", label: "Bro dachte", fallbackEmoji: "😂"),
        Sticker(id: "diskussion", label: "Diskussion beendet", fallbackEmoji: "👑"),
        Sticker(id: "baba", label: "Baba", fallbackEmoji: "👋"),
        Sticker(id: "hue", label: "Hü? Nie gsehn", fallbackEmoji: "🤔"),
        Sticker(id: "crazy", label: "Das crazy", fallbackEmoji: "🤯"),
        Sticker(id: "1v1", label: "1v1 mich", fallbackEmoji: "🥊"),
        Sticker(id: "bigbrain", label: "Big Brain", fallbackEmoji: "🧠"),
        Sticker(id: "zauber", label: "Lernen? Ich zauber", fallbackEmoji: "⚡"),
        Sticker(id: "naechste", label: "Wer ist der Nächste?", fallbackEmoji: "👀"),
    ]
    static let tokenPrefix = "stk:"
    /// Sticker bleiben etwas länger stehen als Emojis
    static let visibleSeconds: Double = 3
    /// Diese bewegen sich in der Blase (10 fps, 1,6–2 s in Schleife); in der Auswahl reicht das Standbild
    static let animatedIds: Set<String> = ["aura", "gogogo", "1hit", "oida", "crazy", "farming"]
    fileprivate static var animationCache: [String: Data?] = [:]

    static func byId(_ id: String?) -> Sticker? {
        all.first { $0.id == id }
    }

    /// "stk:aura" → Sticker; Emojis und unbekannte Sticker → nil
    static func from(token: String) -> Sticker? {
        guard token.hasPrefix(tokenPrefix) else { return nil }
        return byId(String(token.dropFirst(tokenPrefix.count)))
    }
}

/// Ein angezeigtes Emote (Emoji oder Sticker); die id sorgt dafür, dass dasselbe Emote zweimal hintereinander neu aufploppt.
struct EmoteEvent: Equatable {
    let id = UUID()
    let emoji: String
    var sticker: Sticker? = nil

    var visibleSeconds: Double { sticker == nil ? Emotes.visibleSeconds : Stickers.visibleSeconds }
}

extension EmoteEvent {
    /// Aus Auswahl oder Kurzwahl: Emoji oder "stk:<id>"
    init(token: String) {
        if let sticker = Stickers.from(token: token) {
            self.init(emoji: sticker.fallbackEmoji, sticker: sticker)
        } else {
            self.init(emoji: token)
        }
    }
}

/// Sticker-Bild (hat schon einen weißen Rand, braucht keine Blase); `animated` spielt die bewegte Fassung, falls es eine gibt.
struct StickerImage: View {
    let sticker: Sticker
    var size: CGFloat
    var animated = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animated, !reduceMotion, let data = sticker.animationData {
                AnimatedStickerImage(data: data, still: sticker.assetName)
            } else {
                Image(sticker.assetName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Sticker: \(sticker.label)")
    }
}

/// Spielt ein animiertes WebP ab (ImageIO liefert die Bilder im Takt der Datei); bis zum ersten Bild das Standbild.
private struct AnimatedStickerImage: View {
    let data: Data
    let still: String

    @State private var frame: CGImage?
    @State private var player = StickerPlayer()

    var body: some View {
        Group {
            if let frame {
                Image(decorative: frame, scale: 1).resizable().scaledToFit()
            } else {
                Image(still).resizable().scaledToFit()
            }
        }
        .onAppear { player.play(data) { frame = $0 } }
        .onDisappear { player.stop() }
    }
}

/// Hält das Abspielen an, sobald die Blase verschwindet (sonst liefe ImageIO in der Schleife weiter).
private final class StickerPlayer {
    private var running = false

    func play(_ data: Data, onFrame: @escaping (CGImage) -> Void) {
        guard !running else { return }
        running = true
        // Block kommt auf der Main-Queue
        CGAnimateImageDataWithBlock(data as CFData, nil) { [weak self] _, image, stop in
            guard let self, self.running else { stop.pointee = true; return }
            onFrame(image)
        }
    }

    func stop() { running = false }
}

/// Emoji oder Sticker in Kurzwahl und Auswahl ("🔥" oder "stk:aura").
struct EmoteGlyph: View {
    let token: String
    var emojiSize: CGFloat = 22
    var stickerSize: CGFloat = 40

    var body: some View {
        if let sticker = Stickers.from(token: token) {
            StickerImage(sticker: sticker, size: stickerSize)
        } else {
            Text(token).font(.system(size: emojiSize))
        }
    }
}

/// Sprechblase mit Emote über einer Figur (Battle, eigener Pin auf der Karte).
/// Sticker stehen ohne Kreis und wachsen nach oben – die Unterkante bleibt dort, wo die Emoji-Blase endet.
struct EmoteBubble: View {
    let event: EmoteEvent?
    var stickerSize: CGFloat = 104

    /// Höhe der Emoji-Blase (34 pt Emoji + Rand)
    private static let emojiBubbleHeight: CGFloat = 60

    var body: some View {
        ZStack {
            if let event {
                Group {
                    if let sticker = event.sticker {
                        StickerImage(sticker: sticker, size: stickerSize, animated: true)
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                            .frame(height: Self.emojiBubbleHeight, alignment: .bottom)
                    } else {
                        Text(event.emoji)
                            .font(.system(size: 34))
                            .padding(10)
                            .background(Circle().fill(.white))
                            .overlay(Circle().stroke(Color.challengrDark.opacity(0.2), lineWidth: 1))
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    }
                }
                .id(event.id)
                .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: event)
        .allowsHitTesting(false)
    }
}

// MARK: - Hotspot

/// Hotspot auf der Karte: 3D-Münze schwebt hoch über einem Lichtstrahl und einer gelben Bodenplatte –
/// so hebt sie sich klar von Spielern ab, auch wenn man direkt daneben steht. Grau mit Haken, wenn heute erledigt.
struct HotspotMarker: View {
    let name: String
    let checkedIn: Bool
    /// Orte aus OpenStreetMap: Symbol (Park, Brunnen …) – kleiner und niedriger als die Schule, damit die Karte ruhig bleibt
    var symbol: String? = nil

    /// Wie hoch die Münze über dem Boden schwebt (höher als eine Figur)
    static let coinLift: CGFloat = 96
    private var lift: CGFloat { symbol == nil ? Self.coinLift : 58 }
    private var coinSize: CGFloat { symbol == nil ? 50 : 38 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mapNight) private var night

    var body: some View {
        // Erledigt: nur noch jede halbe Minute neu zeichnen (Countdown), sonst flüssig schweben
        TimelineView(.animation(minimumInterval: checkedIn ? 30 : 1 / 20, paused: reduceMotion && !checkedIn)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let hover = (reduceMotion || checkedIn) ? 0 : CGFloat(sin(t * 2.4) * 4)
            let pulse = MapVibe.ripplePhase(time: t, period: 1.6)
            let accent = checkedIn ? Color.gray : Color.challengrYellow
            ZStack(alignment: .bottom) {
                if !checkedIn && !reduceMotion {
                    Ellipse()
                        .stroke(Color.challengrYellow.opacity(0.9 * (1 - pulse)), lineWidth: 3)
                        .frame(width: 60 + 50 * pulse, height: (60 + 50 * pulse) * MapVibe.groundRatio)
                        .offset(y: (60 + 50 * pulse) * MapVibe.groundRatio / 2 - 14)
                }
                // Bodenplatte
                Ellipse()
                    .fill(accent.opacity(0.35))
                    .overlay(Ellipse().stroke(accent, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])))
                    .frame(width: 62, height: 62 * MapVibe.groundRatio)
                // Lichtstrahl vom Boden zur Münze
                LinearGradient(colors: [accent.opacity(0), accent.opacity(checkedIn ? 0.35 : 0.75)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: 10, height: lift)
                    .clipShape(Capsule())
                    .offset(y: -14)
                Image("MenuCoin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: coinSize, height: coinSize)
                    .saturation(checkedIn ? 0 : 1)
                    .opacity(checkedIn ? 0.8 : 1)
                    // nachts glüht die Münze
                    .shadow(color: night && !checkedIn ? Color.challengrYellow.opacity(0.9) : .black.opacity(0.25),
                            radius: night ? 12 : 4, y: night ? 0 : 3)
                    .offset(y: -lift + hover)
                    .overlay(alignment: .bottomTrailing) {
                        if let symbol {
                            Image(systemName: symbol)
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Color.challengrDark))
                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                .offset(x: 5, y: -lift + 4)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if checkedIn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white, Color.challengrGreen)
                                .offset(x: 4, y: -lift)
                        }
                    }
                    .overlay(alignment: .top) {
                        // Countdown bis man wieder einchecken kann
                        if checkedIn {
                            Label(HotspotSchedule.shortText(until: HotspotSchedule.nextCheckin(after: context.date), now: context.date),
                                  systemImage: "clock.fill")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.challengrDark.opacity(0.85)))
                                .fixedSize()
                                .offset(y: -lift - 18)
                        }
                    }
            }
            .frame(width: 110, height: lift + 76, alignment: .bottom)
        }
        .accessibilityElement()
        .accessibilityLabel("Hotspot \(name)\(checkedIn ? ", heute erledigt" : "")")
    }
}
