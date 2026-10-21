import SwiftUI

/// Challengr-Look für die Apple-Karte (MapKit erlaubt keine eigenen Kartenstile): warme Tönung in den
/// Markenfarben und ein dunkler Rand wie in den Spiel-Screens. Liegt über der Karte, lässt alle Berührungen durch.
/// Nachts tritt sie zurück, dann übernimmt der Nachthimmel (SkyOverlay).
struct ChallengrMapGrade: View {
    /// 0 = Tag, 1 = Nacht
    var night: Double = 0

    var body: some View {
        ZStack {
            // warme Creme-Rosé-Tönung wie Login und Spiel-Screens (Karte ist dazu gedämpft: emphasis .muted)
            Color(red: 1.0, green: 0.86, blue: 0.84)
                .blendMode(.multiply)
                .opacity(1 - night * 0.7)
            // Rand ins dunkle Challengr-Rot, Mitte frei (dort steht die eigene Figur)
            GeometryReader { geo in
                RadialGradient(colors: [.clear, .clear, Color.challengrDark.opacity(0.6)],
                               center: .center, startRadius: 0,
                               endRadius: max(geo.size.width, geo.size.height) * 0.65)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
