//
//  UserProfileView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 04.03.26.
//
import SwiftUI

struct UserProfileView: View {
    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Image("playerBoy")
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.yellow, lineWidth: 4)
                )
                .shadow(radius: 10)

            Text("Eigenerspieler")
                .font(.system(size: 24, weight: .bold))

            Text("Level 7 • 123 Trophäen")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}
