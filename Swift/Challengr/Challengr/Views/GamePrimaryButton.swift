//
//  GamePrimaryButton.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 17.02.26.
//


import SwiftUI

struct GamePrimaryButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 16, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundColor(.challengrDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(color)
                )
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 6)
        }
    }
}

struct GameCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

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
