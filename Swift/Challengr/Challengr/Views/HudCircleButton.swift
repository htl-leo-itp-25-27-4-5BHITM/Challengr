//
//  HudCircleButton.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 07.03.26.
//
import SwiftUI

struct HudCircleButton: View {
    let systemName: String

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

struct CompassView: View {
    let angle: Angle
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 38, height: 38)
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)

                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)

                Triangle()
                    .fill(
                        LinearGradient(
                            colors: [.challengrRed, .challengrYellow],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 10, height: 18)
                    .offset(y: -6)
                    .rotationEffect(angle)

                Text("N")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(.challengrBlack.opacity(0.7))
                    .offset(y: 9)
            }
        }
        .buttonStyle(.plain)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

