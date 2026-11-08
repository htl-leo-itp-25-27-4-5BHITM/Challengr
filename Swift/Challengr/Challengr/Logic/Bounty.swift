import SwiftUI

/// Kopfgeld – die Jagd auf den König (Backend: `control.BountyService`).
/// Platz 1 trägt es und leuchtet rot; wer ihn in der Liga besiegt, kassiert den Bonus und trägt es dann selbst.
enum Bounty {
    /// Bonus-Trophäen für den, der den Träger besiegt (wie `BountyService.BONUS`)
    static let bonus = 30
    static let red = Color(red: 1.0, green: 0.16, blue: 0.22)

    /// Schild über dem Kopf des Trägers auf der Karte
    static var tag: some View {
        Label("KOPFGELD", systemImage: "crown.fill")
            .font(.system(size: 9, weight: .black, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(red))
            .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1))
            .shadow(color: red.opacity(0.8), radius: 6)
            .fixedSize()
    }
}
