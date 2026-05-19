//
//  GamePrimaryButton.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 17.02.26.
//


import SwiftUI

struct GamePrimaryButton: View {
    // MARK: - Input (Eingaben)
    let title: String
    let color: Color
    let action: () -> Void

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 17, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundColor(.challengrDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(1.0),
                                    color.opacity(0.78)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        // Subtle glossy highlight
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.55),
                                            Color.white.opacity(0.10),
                                            Color.black.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                                .blendMode(.screen)
                        )
                }
                // Depth
                .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)
                // Colored glow
                .shadow(color: color.opacity(0.35), radius: 18, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }
}

struct GameCard<Content: View>: View {
    // MARK: - Input (Eingaben)
    let content: Content

    // MARK: - Init (Initialisierung)
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.challengrSurface)
        )
        .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 10)
    }
}
