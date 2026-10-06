import SwiftUI

// Gemeinsamer Spiel-Look für Profil und Freunde – wie Battle- und Ergebnis-Screens:
// dunkler Marken-Hintergrund, Glas-Karten, Gelb als Akzent, 3D-Figuren statt Platzhaltern.

enum GameStyle {
    static let background = LinearGradient(colors: [Color.challengrDark, Color.black],
                                           startPoint: .top, endPoint: .bottom)
    static let panelFill = Color.white.opacity(0.07)
    static let panelStroke = Color.white.opacity(0.10)
    static let secondaryText = Color.white.opacity(0.62)
}

/// Glas-Karte auf dunklem Grund.
struct GamePanel: ViewModifier {
    var padding: CGFloat = 14
    var cornerRadius: CGFloat = 20
    var highlight: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(GameStyle.panelFill))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(highlight?.opacity(0.7) ?? GameStyle.panelStroke, lineWidth: highlight == nil ? 1 : 2)
            )
    }
}

extension View {
    func gamePanel(padding: CGFloat = 14, cornerRadius: CGFloat = 20, highlight: Color? = nil) -> some View {
        modifier(GamePanel(padding: padding, cornerRadius: cornerRadius, highlight: highlight))
    }
}

/// Abschnitts-Überschrift: "DEINE FREUNDE  3"
struct GameSectionHeader: View {
    let title: String
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundColor(.white.opacity(0.85))
            if let count {
                Text("\(count)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.challengrDark)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.challengrYellow))
            }
            Spacer(minLength: 0)
        }
    }
}

/// Statistik-Kachel mit Symbol.
struct GameStatTile: View {
    let icon: String
    let value: String
    let title: String
    var color: Color = .challengrYellow

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundColor(GameStyle.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .gamePanel(padding: 10, cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}

/// Runder Avatar mit der Figur eines Spielers und Rang-Ring.
struct CharacterBadge: View {
    let character: GameCharacter
    var ringColor: Color = .challengrYellow
    var size: CGFloat = 52

    var body: some View {
        Image(character.avatarImageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .background(Circle().fill(Color.white.opacity(0.9)))
            .clipShape(Circle())
            .overlay(Circle().stroke(ringColor, lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            .accessibilityHidden(true)
    }
}

/// Kleiner Knopf mit Symbol (+ optionalem Text) im Spiel-Look.
struct GamePillButton: View {
    let icon: String
    var title: String? = nil
    var color: Color = .challengrYellow
    var textColor: Color = .challengrDark
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .black))
                if let title {
                    Text(title.uppercased())
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(0.6)
                }
            }
            .foregroundColor(textColor)
            .padding(.horizontal, title == nil ? 11 : 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title ?? "")
    }
}
