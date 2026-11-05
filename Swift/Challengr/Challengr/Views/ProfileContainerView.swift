import SwiftUI
import CoreLocation
import MapKit

struct ProfileContainerView: View {
    let ownPlayerId: String
    /// 0 = DU, 1 = FREUNDE (z.B. aus dem Karten-Menü)
    var initialTab: Int = 0
    let data: UserProfileData
    let battleHistory: [BattleHistoryDTO]
    let profileStatusText: String?
    let profileBadges: [String]
    var rankColor: Color = .gray
    let allChallenges: [ChallengeDTO]
    let socket: GameSocketService?
    
    // Used for Nearby friends suggestions (Option A: reuse Map coordinate)
    var currentCoordinate: CLLocationCoordinate2D? = nil
    /// Für die Einstellungen (Zahnrad oben rechts, wie in den meisten Spielen)
    var auth: KeycloakAuthService? = nil
    var onSettingsClosed: () -> Void = {}
    
    @State private var selectedTab = 0
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss

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

                if auth != nil {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(GameStyle.panelFill))
                            .overlay(Circle().stroke(GameStyle.panelStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Einstellungen")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            TabView(selection: $selectedTab) {
                UserProfileView(
                    playerId: ownPlayerId,
                    data: data,
                    battleHistory: battleHistory,
                    profileStatusText: profileStatusText,
                    profileBadges: profileBadges,
                    rankColor: rankColor
                )
                .tag(0)

                // Auch ohne Standort erreichbar – nur "In der Nähe" braucht ihn (BUG-13)
                FriendsListView(
                    ownPlayerId: ownPlayerId,
                    currentCoordinate: currentCoordinate,
                    allChallenges: allChallenges,
                    socket: socket,
                    onBattleSent: { dismiss() }
                )
                .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            // The scroll views inside handle their own scrolling
        }
        .background(GameStyle.background.ignoresSafeArea())
        // Spiel-Look: immer dunkel (Charts, Textfelder, System-Farben passen sich an)
        .environment(\.colorScheme, .dark)
        .onAppear { selectedTab = initialTab }
        .sheet(isPresented: $showSettings, onDismiss: onSettingsClosed) {
            if let auth { SettingsView(auth: auth) }
        }
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
                .font(.system(size: 14, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundColor(isSelected ? .challengrDark : .white.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(isSelected ? Color.challengrYellow : GameStyle.panelFill)
                )
                .overlay(Capsule().stroke(isSelected ? Color.clear : GameStyle.panelStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
