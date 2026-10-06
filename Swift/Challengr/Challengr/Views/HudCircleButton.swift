//
//  HudCircleButton.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 07.03.26.
//
import SwiftUI

struct HudCircleButton: View {
    // MARK: - Input (Eingaben)
    let systemName: String

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)

            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.challengrBlack)
        }
    }
}

/// Kompass der Karte: die Rose dreht sich gegen die Kartenrichtung, das rote Dreieck mit "N"
/// zeigt also immer nach Norden. Tippen richtet die Karte wieder nach Norden aus.
struct CompassView: View {
    // MARK: - Input (Eingaben)
    /// Blickrichtung der Karte (0° = Norden oben)
    let angle: Angle
    let onTap: () -> Void

    /// Karte schaut (fast) nach Norden → Rose ruhig, sonst rote Umrandung als Hinweis "tippen".
    private var isNorthUp: Bool {
        let d = angle.degrees.truncatingRemainder(dividingBy: 360)
        return abs(d) < 2 || abs(abs(d) - 360) < 2
    }

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 3)
                Circle()
                    .stroke(isNorthUp ? Color.challengrDark.opacity(0.12) : Color.challengrRed.opacity(0.7), lineWidth: 2)

                // Rose: dreht sich gegen die Karte
                ZStack {
                    ForEach(0..<16, id: \.self) { i in
                        Capsule()
                            .fill(Color.challengrDark.opacity(i % 4 == 0 ? 0.55 : 0.2))
                            .frame(width: i % 4 == 0 ? 2 : 1.2, height: i % 4 == 0 ? 5 : 3)
                            .offset(y: -17.5)
                            .rotationEffect(.degrees(Double(i) * 22.5))
                    }
                    Triangle()
                        .fill(Color.challengrRed)
                        .frame(width: 10, height: 8)
                        .offset(y: -15)
                    Text("N")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.challengrRed)
                        .offset(y: -4)
                    Text("S")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(.challengrDark.opacity(0.45))
                        .offset(y: 12)
                }
                .rotationEffect(-angle)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: angle.degrees)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Kompass")
        .accessibilityValue(isNorthUp ? "Norden oben" : "Karte gedreht – tippen für Norden")
    }
}

/// Circular avatar-style map pin. Shows the player's character (own figure, or the
/// opponent figure for other players – their real choice isn't known server-side);
/// without an image it falls back to a generic silhouette.
struct MapAvatarPin: View {
    let imageName: String?
    let ringColor: Color
    let isOwnPlayer: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.25))
                .frame(width: 44, height: 44)
                .blur(radius: 4)
                .offset(y: 3)

            Circle()
                .fill(isOwnPlayer ? Color.white : Color.challengrDark)
                .frame(width: 40, height: 40)

            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            Circle()
                .stroke(ringColor, lineWidth: 3)
                .frame(width: 40, height: 40)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

struct Triangle: Shape {
    // MARK: - Drawing (Zeichnen)
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

