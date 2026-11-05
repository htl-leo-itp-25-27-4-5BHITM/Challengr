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

    /// Dunkle Spielkarte für Fenster über der Karte (Spieler-Popup, Herausfordern) – wie Battle- und Sticker-Screens.
    func gameOverlayCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(GameOverlayCard(cornerRadius: cornerRadius))
    }
}

/// Feedback 04.11. ("Overlay passender zu Challengr"): statt heller Glas-Karte dunkel mit Marken-Rot.
struct GameOverlayCard: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.24, green: 0.04, blue: 0.11), Color.challengrDark],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            .environment(\.colorScheme, .dark)
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
            .background(CharacterBackdrop(character: character))
            .clipShape(Circle())
            .overlay(Circle().stroke(ringColor, lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            .accessibilityHidden(true)
    }
}

/// Runder Hintergrund in der Farbe der Figur (hell in der Mitte, dunkler am Rand).
struct CharacterBackdrop: View {
    let character: GameCharacter

    var body: some View {
        Circle().fill(RadialGradient(colors: [character.themeColor.opacity(0.55), character.themeColor],
                                     center: .center, startRadius: 2, endRadius: 40))
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
