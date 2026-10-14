import SwiftUI

/// Himmel über der 3D-Karte: Morgen-/Abendrot in der Dämmerung, nachts dunkelblauer Himmel mit Sternen.
/// Liegt über der Karte und lässt alle Berührungen durch. Rein dekorativ.
struct SkyOverlay: View {
    let sky: SkyState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mapCrowded) private var crowded

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if sky.night > 0.01 {
                    // ganz leichter Blaustich über allem, oben dunkler Himmel
                    Color(red: 0.05, green: 0.08, blue: 0.25)
                        .opacity(0.14 * sky.night)
                    LinearGradient(colors: [Color(red: 0.03, green: 0.04, blue: 0.16).opacity(0.85), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: geo.size.height * 0.42)
                        .opacity(sky.night)
                    stars(in: CGSize(width: geo.size.width, height: geo.size.height * 0.32))
                        .opacity(sky.night)
                }
                // Dämmerung über dem Nachthimmel, damit Morgen-/Abendrot auch auf der dunklen Karte leuchtet
                if sky.twilight > 0.01 {
                    LinearGradient(colors: twilightColors, startPoint: .top, endPoint: .bottom)
                        .frame(height: geo.size.height * 0.55)
                        .opacity(sky.twilight)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 2), value: sky)
        .accessibilityHidden(true)
    }

    /// Abends Orange/Rosa, morgens Rosa/Pfirsich.
    private var twilightColors: [Color] {
        sky.rising
            ? [Color(red: 1.0, green: 0.5, blue: 0.62).opacity(0.5), Color(red: 1.0, green: 0.72, blue: 0.5).opacity(0.25), .clear]
            : [Color(red: 1.0, green: 0.45, blue: 0.15).opacity(0.42), Color(red: 0.95, green: 0.35, blue: 0.45).opacity(0.2), .clear]
    }

    /// Sterne an festen Stellen, die sanft funkeln (bei vielen Spielern oder reduzierter Bewegung ruhig).
    private func stars(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 8, paused: reduceMotion || crowded)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, _ in
                for i in 0..<StarField.count {
                    let star = StarField.star(i)
                    let x = star.x * size.width
                    let y = star.y * size.height
                    // nach unten hin schwächer, damit sie in den Himmel über der Karte übergehen
                    let fade = 1 - star.y * 0.8
                    let twinkle = reduceMotion || crowded ? 0.8 : 0.55 + 0.45 * sin(t * star.speed + star.phase)
                    let r = star.size
                    ctx.opacity = fade * twinkle
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white))
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

/// Feste, gleichmäßig verteilte Sterne (Pseudozufall aus dem Index – kein Springen zwischen Frames).
enum StarField {
    static let count = 45

    struct Star { let x: Double; let y: Double; let size: Double; let speed: Double; let phase: Double }

    static func star(_ i: Int) -> Star {
        func rnd(_ k: Double) -> Double {
            let v = sin(Double(i) * 12.9898 + k * 78.233) * 43_758.5453
            return v - floor(v)
        }
        return Star(x: rnd(1), y: pow(rnd(2), 1.4), size: 0.6 + rnd(3) * 1.2,
                    speed: 1.2 + rnd(4) * 2.5, phase: rnd(5) * 6.28)
    }
}

// MARK: - Nacht für Karten-Figuren (leuchten stärker)

private struct MapNightKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Nachts leuchten Figuren und Hotspots auf der Karte stärker (nur Optik).
    var mapNight: Bool {
        get { self[MapNightKey.self] }
        set { self[MapNightKey.self] = newValue }
    }
}
