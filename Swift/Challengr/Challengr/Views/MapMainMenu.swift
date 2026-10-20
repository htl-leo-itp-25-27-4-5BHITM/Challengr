import SwiftUI

/// Ein Eintrag im Haupt-Menü der Karte.
struct MapMenuItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let color: Color
    var badge: Int = 0
    let action: () -> Void
}

/// Haupt-Button der Karte (3D-Blitz-Münze) – öffnet wie bei Pokémon GO ein Menü im Bogen.
struct MapMainMenu: View {
    @Binding var isOpen: Bool
    let items: [MapMenuItem]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = 0.0

    var body: some View {
        ZStack(alignment: .bottom) {
            if isOpen {
                // Tipp daneben schließt das Menü
                // Tipp daneben schließt nur – nie öffnen (sonst ging es während der
                // Schließ-Animation durch einen weiteren Tipp wieder auf)
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
            }

            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    // ab 6 Knöpfen etwas weiterer Bogen, sonst stoßen sie aneinander
                    let offset = MapMenuLayout.offset(index: index, count: items.count,
                                                      radius: items.count > 5 ? 170 : MapMenuLayout.radius)
                    menuButton(item)
                        .offset(x: isOpen ? offset.width : 0, y: isOpen ? offset.height : 0)
                        .scaleEffect(isOpen ? 1 : 0.2)
                        .opacity(isOpen ? 1 : 0)
                        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.72)
                                    .delay(isOpen ? Double(index) * 0.035 : 0), value: isOpen)
                        .allowsHitTesting(isOpen)
                }

                coinButton
            }
            .padding(.bottom, 30)
        }
        // Immer ganze Fläche, Münze unten – sonst würde sie geschlossen in die Mitte rutschen
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var coinButton: some View {
        Button(action: toggle) {
            ZStack {
                Image("MenuCoin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)

                // Geschlossen: roter Punkt, wenn im Menü etwas wartet (z. B. Aufgaben-Belohnung)
                if !isOpen, items.contains(where: { $0.badge > 0 }) {
                    Circle()
                        .fill(Color.challengrRed)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .offset(x: 30, y: -30)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }

                if isOpen {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.challengrDark))
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 30, y: -30)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOpen ? "Menü schließen" : "Menü")
    }

    private func menuButton(_ item: MapMenuItem) -> some View {
        Button {
            close()   // spielt den Klick
            item.action()
        } label: {
            // Nur Symbole – die Namen stehen in der Bedienungshilfe (VoiceOver)
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(item.color))
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    if item.badge > 0 {
                        Text("\(item.badge)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Capsule().fill(Color.challengrRed))
                            .offset(x: 6, y: -4)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }

    private func close() {
        guard isOpen else { return }
        toggle()
    }

    private func toggle() {
        SoundManager.shared.play(isOpen ? .click : .menuOpen)
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7)) {
            isOpen.toggle()
            spin += 360
        }
    }
}

/// Position der Menü-Buttons auf einem Bogen über der Münze (testbar).
enum MapMenuLayout {
    static let radius: CGFloat = 150

    /// Von links (145°) nach rechts (35°), gleichmäßig verteilt; y nach oben ist negativ.
    /// Nicht flacher, sonst überdeckt der linke Button das Profilbild unten links.
    static func offset(index: Int, count: Int, radius: CGFloat = radius) -> CGSize {
        guard count > 1 else { return CGSize(width: 0, height: -radius) }
        let start = 145.0, end = 35.0
        let angle = (start + (end - start) * Double(index) / Double(count - 1)) * .pi / 180
        return CGSize(width: cos(angle) * radius, height: -sin(angle) * radius)
    }
}
