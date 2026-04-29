import SwiftUI

struct Friend: Identifiable {
    let id = UUID()
    let name: String
    let avatarName: String
    let bondLevel: Int // 0...5
    let lastAction: String
    let lastOnline: String
}

struct FriendsListView: View {
    private let challengrRed = Color(red: 0.73, green: 0.12, blue: 0.20)
    private let challengrDark = Color(red: 0.12, green: 0.00, blue: 0.05)
    private let cardBackground = Color.white

    private let friends: [Friend] = [
        Friend(
            name: "AlexRunner",
            avatarName: "person.crop.circle.fill",
            bondLevel: 5,
            lastAction: "Hat zuletzt eine iPhone-Challenge gespielt.",
            lastOnline: "vor 2 Monaten"
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Freunde")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(challengrDark)

                HStack(spacing: 12) {
                    FriendActionButton(
                        icon: "person.badge.plus",
                        title: "Hinzufügen",
                        foreground: challengrRed,
                        background: challengrRed.opacity(0.12)
                    )

                    FriendActionButton(
                        icon: "magnifyingglass",
                        title: "Suchen",
                        foreground: challengrDark,
                        background: challengrDark.opacity(0.08)
                    )
                }

                ForEach(friends) { friend in
                    FriendRow(
                        friend: friend,
                        challengrRed: challengrRed,
                        challengrDark: challengrDark,
                        cardBackground: cardBackground
                    )
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct FriendActionButton: View {
    let icon: String
    let title: String
    let foreground: Color
    let background: Color

    var body: some View {
        Button {
            // Statischer Prototyp: noch ohne Funktion
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(background)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct FriendRow: View {
    let friend: Friend
    let challengrRed: Color
    let challengrDark: Color
    let cardBackground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: friend.avatarName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .foregroundColor(challengrDark.opacity(0.75))
                    .padding(6)
                    .background(challengrDark.opacity(0.08))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(friend.name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(challengrDark)

                    Text(friend.lastAction)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(challengrDark.opacity(0.8))
                }

                Spacer()

                Text(friend.lastOnline)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Challenge-Bindung")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                BondMeter(level: friend.bondLevel, activeColor: challengrRed)
            }
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(challengrRed.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
    }
}

struct BondMeter: View {
    let level: Int
    let activeColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index < level ? activeColor : Color.gray.opacity(0.25))
                    .frame(width: 26, height: 8)
            }
        }
    }
}

struct FriendsListView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsListView()
    }
}