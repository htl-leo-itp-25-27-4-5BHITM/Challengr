import SwiftUI

struct ProfileContainerView: View {
    let data: UserProfileData
    let pointsHistory: [PlayerPointsHistoryDTO]
    let battleHistory: [BattleHistoryDTO]
    let profileStatusText: String?
    let profileBadges: [String]
    
    @State private var selectedTab = 0

    private let challengrRed = Color(red: 0.73, green: 0.12, blue: 0.20)
    private let challengrDark = Color(red: 0.12, green: 0.00, blue: 0.05)
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ProfileSegmentButton(
                    title: "DU",
                    isSelected: selectedTab == 0,
                    activeColor: challengrRed,
                    textColor: challengrDark
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 0 }
                }

                ProfileSegmentButton(
                    title: "FREUNDE",
                    isSelected: selectedTab == 1,
                    activeColor: challengrRed,
                    textColor: challengrDark
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 1 }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color(.systemGroupedBackground))
            
            Divider().padding(.vertical, 8)
            
            TabView(selection: $selectedTab) {
                UserProfileView(
                    data: data,
                    pointsHistory: pointsHistory,
                    battleHistory: battleHistory,
                    profileStatusText: profileStatusText,
                    profileBadges: profileBadges
                )
                .tag(0)
                
                FriendsListView()
                .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            // The scroll views inside handle their own scrolling
        }
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}

private struct ProfileSegmentButton: View {
    let title: String
    let isSelected: Bool
    let activeColor: Color
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isSelected ? .white : textColor.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? activeColor : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(activeColor.opacity(isSelected ? 0 : 0.28), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
