import SwiftUI

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

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .bottom) {
                // Boden: Wellen, Schatten, Ring – flach gedrückt, damit sie auf der Karte "liegen"
                if sonar && !reduceMotion {
                    ForEach(0..<2, id: \.self) { i in
                        let p = MapVibe.ripplePhase(time: t, offset: Double(i) * 0.5)
                        Ellipse()
                            .stroke(ringColor.opacity(0.8 * (1 - p)), lineWidth: 3)
                            .frame(width: 50 + 90 * p, height: (50 + 90 * p) * 0.36)
                            .offset(y: (50 + 90 * p) * 0.18 - 9)
                    }
                }
                Ellipse()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 42, height: 13)
                    .blur(radius: 2)
                Ellipse()
                    .stroke(ringColor, lineWidth: 3)
                    .frame(width: 50, height: 18)

                if let frame = MapSprites.frame(of: character,
                                                at: reduceMotion ? 0 : MapVibe.spriteFrame(time: t, seed: seed)) {
                    Image(uiImage: frame)
                        .resizable()
                        .scaledToFit()
                        .frame(height: height)
                        .offset(y: -7)
                }
            }
            .frame(width: height * 1.6, height: height + 12, alignment: .bottom)
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

    static func frame(of character: GameCharacter, at index: Int) -> UIImage? {
        let all = frames(of: character)
        return all.isEmpty ? nil : all[index % all.count]
    }
}

/// Wer auf der Karte angezeigt wird. Für die Demo nur die beiden Test-Apps;
/// leer lassen, um wieder alle Spieler zu zeigen.
enum MapPlayerFilter {
    static var allowedNames: [String] = ["test", "cookieclicker"]

    static func isVisible(name: String) -> Bool {
        guard !allowedNames.isEmpty else { return true }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allowedNames.contains { $0.lowercased() == n }
    }
}

/// Pin eines anderen Spielers: wippt leicht im eigenen Takt, ploppt beim Erscheinen auf
/// und zeigt ab und zu eine Emoji-Blase.
struct LivelyPin<Content: View>: View {
    let seed: String
    var bubble: String? = nil
    /// Figuren-Pins bewegen sich schon selbst
    var bobs = true
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let bob = (reduceMotion || !bobs) ? 0 : MapVibe.bobOffset(time: context.date.timeIntervalSinceReferenceDate, seed: seed)
            content
                .offset(y: bob)
                .overlay(alignment: .top) {
                    if let bubble {
                        Text(bubble)
                            .font(.system(size: 18))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.white))
                            .overlay(Capsule().stroke(Color.challengrBlack.opacity(0.15), lineWidth: 1))
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                            .offset(y: (bobs ? -40 : -24) + bob)
                            .transition(.scale(scale: 0.3, anchor: .bottom).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
        }
        .scaleEffect(appeared || reduceMotion ? 1 : 0.2)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { appeared = true }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: bubble)
    }
}

/// Reine Rechenlogik der Karten-Effekte (testbar).
enum MapVibe {
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
    static let all = ["🔥", "😤", "💪", "👀", "🏆", "😂", "👋", "🥊"]
    /// Kurze Auswahl für die Karte (Begrüßen/Necken).
    static let map = ["👋", "🔥", "😤", "💪"]
    /// Wie lange eine Emote-Blase sichtbar bleibt.
    static let visibleSeconds: Double = 2.5
}

/// Ein angezeigtes Emote; die id sorgt dafür, dass dasselbe Emoji zweimal hintereinander neu aufploppt.
struct EmoteEvent: Equatable {
    let id = UUID()
    let emoji: String
}

/// Sprechblase mit Emote über einer Figur (Battle).
struct EmoteBubble: View {
    let event: EmoteEvent?

    var body: some View {
        ZStack {
            if let event {
                Text(event.emoji)
                    .font(.system(size: 34))
                    .padding(10)
                    .background(Circle().fill(.white))
                    .overlay(Circle().stroke(Color.challengrDark.opacity(0.2), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    .id(event.id)
                    .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: event)
        .allowsHitTesting(false)
    }
}

// MARK: - Hotspot

/// Hotspot auf der Karte: schwebende 3D-Münze über einem Bodenring. Grau mit Haken, wenn heute erledigt.
struct HotspotMarker: View {
    let name: String
    let checkedIn: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Erledigt: nur noch jede halbe Minute neu zeichnen (Countdown), sonst flüssig schweben
        TimelineView(.animation(minimumInterval: checkedIn ? 30 : 1 / 20, paused: reduceMotion && !checkedIn)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let hover = (reduceMotion || checkedIn) ? 0 : CGFloat(sin(t * 2.4) * 4)
            let pulse = MapVibe.ripplePhase(time: t, period: 1.6)
            ZStack(alignment: .bottom) {
                if !checkedIn && !reduceMotion {
                    Ellipse()
                        .stroke(Color.challengrYellow.opacity(0.9 * (1 - pulse)), lineWidth: 3)
                        .frame(width: 44 + 50 * pulse, height: (44 + 50 * pulse) * 0.36)
                        .offset(y: (44 + 50 * pulse) * 0.18 - 9)
                }
                Ellipse()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 34, height: 11)
                    .blur(radius: 2)
                Image("MenuCoin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .saturation(checkedIn ? 0 : 1)
                    .opacity(checkedIn ? 0.75 : 1)
                    .offset(y: -16 + hover)
                    .overlay(alignment: .topTrailing) {
                        if checkedIn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white, Color.challengrGreen)
                                .offset(x: 4, y: -16)
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
                                .offset(y: -34)
                        }
                    }
            }
            .frame(width: 100, height: 76, alignment: .bottom)
        }
        .accessibilityElement()
        .accessibilityLabel("Hotspot \(name)\(checkedIn ? ", heute erledigt" : "")")
    }
}
