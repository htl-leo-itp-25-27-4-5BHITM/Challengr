import SwiftUI

/// Simple public friend profile view (MVP).
/// Shows a placeholder avatar plus name, points and rank based on `PlayerDTO`.
struct FriendProfileView: View {
    let friend: PlayerDTO

    private let challengrDark = Color(red: 0.12, green: 0.00, blue: 0.05)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .foregroundColor(challengrDark.opacity(0.75))
                    .padding(10)
                    .background(challengrDark.opacity(0.08))
                    .clipShape(Circle())
                    .padding(.top, 12)

                Text(friend.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(challengrDark)

                Text("\(friend.points) Punkte")
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        FriendStatBox(title: "Rang", value: friend.rankName)
                        FriendStatBox(title: "Punkte", value: "\(friend.points)")
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FriendStatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        )
    }
}
