//
//  UserProfileView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 04.03.26.
//
import SwiftUI

struct UserProfileData {
    let name: String
    let avatarImageName: String
    let rankName: String
    let dailyStreak: Int
    let totalChallenges: Int
    let wonChallenges: Int
    let points: Int
}

struct UserProfileView: View {
    let data: UserProfileData

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Image(data.avatarImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.yellow, lineWidth: 4)
                )
                .shadow(radius: 10)

            Text(data.name)
                .font(.system(size: 24, weight: .bold))

            Text("\(data.points) Punkte")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    StatBox(title: "Tagesstreak",
                            value: "\(data.dailyStreak) 🔥")
                    StatBox(title: "Challenges",
                            value: "\(data.totalChallenges)")
                }

                HStack(spacing: 12) {
                    StatBox(title: "Gewonnen",
                            value: "\(data.wonChallenges)")
                    StatBox(title: "Rang",
                            value: data.rankName)
                }
            }
            .padding(.top, 8)

            Spacer()    // unten Platz für Statistik
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08),
                        radius: 6, x: 0, y: 3)
        )
    }
}
