import SwiftUI

/// Figuren-Stufen 1–10 aus Liga-Siegen mit einer Figur (Backend: `control.CharacterLevel`).
/// Ab Stufe 3 Bronze-, ab 6 Silber-, auf 10 Gold-Aura.
enum CharacterLevel {
    /// Siege, ab denen eine Stufe erreicht ist (Index = Stufe - 1) – wie im Backend
    static let wins = [0, 1, 3, 6, 10, 15, 21, 28, 36, 45]
    static let max = wins.count

    enum Tier: Int, Comparable {
        case none, bronze, silver, gold

        static func < (a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue }

        var name: String {
            switch self {
            case .none:   return ""
            case .bronze: return "Bronze-Aura"
            case .silver: return "Silber-Aura"
            case .gold:   return "Gold-Aura"
            }
        }

        var color: Color {
            switch self {
            case .none:   return .clear
            case .bronze: return Color(red: 0.85, green: 0.52, blue: 0.25)
            case .silver: return Color(red: 0.78, green: 0.86, blue: 0.95)
            case .gold:   return Color(red: 1.0, green: 0.82, blue: 0.2)
            }
        }
    }

    static func tier(_ level: Int) -> Tier {
        switch level {
        case 10...: return .gold
        case 6...:  return .silver
        case 3...:  return .bronze
        default:    return .none
        }
    }

    static func level(wins w: Int) -> Int {
        (wins.lastIndex { w >= $0 } ?? 0) + 1
    }
}

/// Aura unter einer Figur auf der Karte: Bronze/Silber pulsieren, Gold mit Funken.
struct LevelAura: View {
    let level: Int
    let time: TimeInterval

    var body: some View {
        let tier = CharacterLevel.tier(level)
        if tier != .none {
            let pulse = (sin(time * 2.5) + 1) / 2
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [tier.color.opacity(0.75), tier.color.opacity(0)], center: .center, startRadius: 4, endRadius: 46))
                    .frame(width: 84 + 10 * pulse, height: (84 + 10 * pulse) * MapVibe.groundRatio)
                if tier == .gold {
                    ForEach(0..<6, id: \.self) { i in
                        let a = time * 1.6 + Double(i) * .pi / 3
                        let rise = (time * 0.8 + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4, height: 4)
                            .shadow(color: tier.color, radius: 4)
                            .offset(x: cos(a) * 30, y: sin(a) * 30 * MapVibe.groundRatio - rise * 60)
                            .opacity(1 - rise)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// Stufen-Plakette ("7") am Avatar/Pin.
struct LevelPlate: View {
    let level: Int

    var body: some View {
        let tier = CharacterLevel.tier(level)
        Text("\(level)")
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(tier == .none ? .white : .challengrDark)
            .frame(minWidth: 18, minHeight: 18)
            .background(Circle().fill(tier == .none ? Color.black.opacity(0.6) : tier.color))
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .accessibilityLabel("Stufe \(level)")
    }
}
