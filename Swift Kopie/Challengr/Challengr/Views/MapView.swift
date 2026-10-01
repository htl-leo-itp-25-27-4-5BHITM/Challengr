// MARK: - Imports (Importe)

import SwiftUI
import MapKit
import CoreLocation
import CoreLocationUI
import Combine
import UIKit

extension Color {
    static let challengrRed     = Color(red: 0.73, green: 0.12, blue: 0.20)   // #BA1F33
    static let challengrDark    = Color(red: 0.12, green: 0.00, blue: 0.05)   // #1E000E
    static let challengrSurface = Color(red: 0.98, green: 0.98, blue: 0.98)   // #F9F9F9

    /// Schrift direkt auf dem System-Hintergrund: hell = Challengr-Dunkel, dunkel = Weiß.
    /// (Auf den festen, hellen Spielkarten bleibt es beim festen challengrDark.)
    static let challengrInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .white
            : UIColor(red: 0.12, green: 0.00, blue: 0.05, alpha: 1)
    })

    /// Markenrot, im Dark Mode etwas heller für genug Kontrast auf dunklem Grund.
    static let challengrRedInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.36, blue: 0.43, alpha: 1)
            : UIColor(red: 0.73, green: 0.12, blue: 0.20, alpha: 1)
    })
}

// MARK: - Models (Modelle)

/// Simple model to represent a player as a map annotation.
struct PlayerAnnotation: Identifiable {
    let id = UUID()
    let playerId: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let rankName: String
}

enum ActiveFullScreen {
    case none
    case battle
    case voting
    case win
    case lose
}

enum ActiveOverlay {
    case none
    case resultPending   // 2–3 Sekunden nach Voting/Surrender
}




struct MapView: View {
    
    // MARK: - State & Services + Helpers (State & Services + Helfer)
    
    /// Helper that provides the current user location
    @StateObject private var locationHelper: LocationHelper
    
    /// Services to load from the backend
    private let playerService = PlayerLocationService()
    private let challengesService = ChallengesService()

    /// static player id
    let ownPlayerId: String

    /// Auth is needed for Settings/Logout. Optional for preview/default init.
    private let auth: KeycloakAuthService?
    

    @State private var allChallenges: [ChallengeDTO] = []
    /// Newest battle-requested id per direction; older async resolves must not overwrite it.
    /// (Separate for incoming/outgoing – after a reconnect the server re-sends both.)
    @State private var latestIncomingRequestId: Int64? = nil
    @State private var latestOutgoingRequestId: Int64? = nil

    /// WebSocket
    @StateObject private var socket: GameSocketService

    /// Incoming friend requests (Banner + Badge), live via WebSocket.
    @StateObject private var friendsInbox = FriendsInboxStore()
    @Environment(\.scenePhase) private var scenePhase

    /// Short info banner at the top of the map (z.B. "Anfrage abgelaufen").
    @State private var mapBanner: (icon: String, text: String)? = nil
    @State private var mapBannerHideTask: Task<Void, Never>? = nil
    
    /// Information about an incoming challenge from another player.
    @State private var incomingChallenge: (
        battleId: Int64,
        fromId: String,
        challengeId: Int64,
        name: String,
        category: String
    )? = nil
    
    @State private var outgoingBattleInfo: (
        battleId: Int64,
        opponentId: String,
        challengeName: String,
        category: String
    )? = nil


    /// Battle Infos and Settings.
    @State private var currentBattleId: Int64? = nil
    @State private var activeBattleInfo: (challengeName: String,
                                          category: String,
                                          playerA: String,
                                          playerB: String,
                                          opponentId: String)? = nil
    @State private var activeFullScreen: ActiveFullScreen = .none
    @State private var resultData: BattleResultData? = nil

    /// Static ownPlayerName & coordinates
    @State private var ownPlayerName: String
    @State private var ownCoordinate: CLLocationCoordinate2D? = nil
    
    @State private var ownRankName: String = "-"
    @State private var ownDailyStreak: Int = 0
    @State private var ownTotalChallenges: Int = 0
    @State private var ownWonChallenges: Int = 0
    @State private var ownPoints: Int = 0
    @State private var pointsHistory: [PlayerPointsHistoryDTO] = []
    @State private var battleHistory: [BattleHistoryDTO] = []
    @State private var profileStatusText: String? = nil
    @State private var profileBadges: [String] = []
    
    @State private var showProfile = false
    @State private var showSettings = false
    @State private var showShop = false
    @State private var currentTargetCoordinate: CLLocationCoordinate2D? = nil

    
    @State private var lastKnowledgeQuestion: (battleId: Int64, text: String, choices: [String], timeLimit: Int?)?


    /// Fallback (Default Map: Vienna)
    private let startCoordinate = CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738)

    @available(*, unavailable, message: "Use MapView(ownPlayerId:ownPlayerName:auth:) so each device connects with its real Keycloak playerId.")
    init() {
        fatalError("Unavailable")
    }

    init(ownPlayerId: Int64, ownPlayerName: String, auth: KeycloakAuthService) {
        let resolvedPlayerName = ownPlayerName.isEmpty ? "Player" : ownPlayerName
        let resolvedPlayerId = String(ownPlayerId)

        self.ownPlayerId = resolvedPlayerId
        self.auth = auth
        _ownPlayerName = State(initialValue: resolvedPlayerName)
        _locationHelper = StateObject(wrappedValue: LocationHelper(playerId: resolvedPlayerId, playerName: resolvedPlayerName))
        _socket = StateObject(wrappedValue: GameSocketService(playerId: resolvedPlayerId))
    }

    init(ownPlayerId: String, ownPlayerName: String, auth: KeycloakAuthService) {
        let resolvedPlayerName = ownPlayerName.isEmpty ? "Player" : ownPlayerName

        self.ownPlayerId = ownPlayerId
        self.auth = auth
        _ownPlayerName = State(initialValue: resolvedPlayerName)
        _locationHelper = StateObject(wrappedValue: LocationHelper(playerId: ownPlayerId, playerName: resolvedPlayerName))
        _socket = StateObject(wrappedValue: GameSocketService(playerId: ownPlayerId))
    }

    
    /// Current map camera position and Zoom
    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
            distance: 1000,
            heading: 0,
            pitch: 0
        )
    )
    
    @State private var myVote: String? = nil
    @State private var opponentVote: String? = nil

    @State private var activeOverlay: ActiveOverlay = .none
    @State private var hasCenteredOnUser = false
    @State private var currentZoomDistance: CLLocationDistance = 1000
    @State private var isProgrammaticCameraUpdate = false
    @State private var isFollowingUser = true
    @State private var hasCapturedInitialZoom = false

    let minDistance: CLLocationDistance = 200
    let maxDistance: CLLocationDistance = 5000

    
    /// All players that should be displayed
    @State private var annotations: [PlayerAnnotation] = []

    /// Rank name -> rank color, used to tint player pins on the map.
    @State private var rankColorsByName: [String: Color] = [:]
    private let rankService = RankService()
    
    /// Challenge Infos Window
    @State private var showChallengeView = false
    @State private var showTrophyRoad = false

    /// Player Selected Infos
    @State private var selectedPlayer: PlayerAnnotation? = nil
    @State private var showPlayerPopup = false
    @State private var showPlayerChallengeDialog = false

    @State private var showNearbyText = true

    // Periodic refresh so newly appearing players are shown even if our own GPS
    // coordinate does not change (simulator often stays constant).
    @State private var nearbyRefreshTask: Task<Void, Never>? = nil

    // WebSocket-driven refresh (throttled/debounced) for truly live nearby updates.
    @State private var wsNearbyRefreshTask: Task<Void, Never>? = nil
    @State private var lastWsNearbyRefreshAt: Date? = nil

    
    /// Resolves a challenge text + category for a given ID (Challenge-Infos für ID)
    /// Resolves the challenge that the backend actually stored for a battle.
    /// Order: payload from backend -> local cache -> fetch by id (never guess).
    @MainActor
    private func resolveChallengeInfo(id: Int64, text: String?, category: String?) async -> (name: String, category: String) {
        let service = challengesService
        let resolved = await ChallengeResolver.resolve(
            id: id,
            text: text,
            category: category,
            cached: allChallenges,
            fetch: { try await service.loadChallenge(id: $0) }
        )
        if let fetched = resolved.fetched, !allChallenges.contains(where: { $0.id == fetched.id }) {
            allChallenges.append(fetched)
        }
        return (resolved.name, resolved.category)
    }


    /// Triggers a success haptic feedback (Haptisches Feedback)
    private func vibrate() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - Body (UI-Aufbau)

    @State private var compassAngle: Angle = .zero
    
    var body: some View {
        
        ZStack {
            // Map-Ebene
            mapLayer

            VStack {
                HStack {
                    // LINKS: Capsule "Spieler in meiner Nähe" (ausklappbar)
                    HStack(spacing: 8) {
                        Button {
                            hasCenteredOnUser = true
                            isFollowingUser = true
                            position = .userLocation(
                                followsHeading: false,
                                fallback: .camera(
                                    MapCamera(
                                        centerCoordinate: startCoordinate,
                                        distance: 1000,
                                        heading: 0,
                                        pitch: 0
                                    )
                                )
                            )
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.challengrDark)
                                .padding(7)
                                .background(Color.challengrYellow)
                                .clipShape(Circle())
                        }

                        if showNearbyText {
                            let count = annotations.count
                            let text: String = {
                                switch count {
                                case 0:  return "Noch keine Spieler in deiner Nähe"
                                default: return "\(count) Spieler in meiner Nähe"
                                }
                            }()
                            Text(text)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.challengrDark)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }

                        // Chevron zum Ein-/Ausklappen
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showNearbyText.toggle()
                            }
                        } label: {
                            Image(systemName: showNearbyText ? "chevron.left" : "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.challengrDark.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)

                    Spacer()

                    // RECHTS: Settings OBEN, Kompass UNTEN
                    VStack(spacing: 8) {
                        Button {
                            showSettings = true
                        } label: {
                            HudCircleButton(systemName: "gearshape.fill")
                                .frame(width: 36, height: 36)
                        }

                        Button {
                            showShop = true
                        } label: {
                            HudCircleButton(systemName: "bag.fill")
                                .frame(width: 36, height: 36)
                        }

                        CompassView(angle: compassAngle) {
                            withAnimation(.easeOut(duration: 0.35)) {
                                guard let cam = position.camera else { return }

                                let newCam = MapCamera(
                                    centerCoordinate: cam.centerCoordinate,
                                    distance: cam.distance,
                                    heading: 0,
                                    pitch: cam.pitch
                                )
                                position = .camera(newCam)
                            }
                        }
                        .frame(width: 36, height: 36)
                    }
                }
                .padding(.top, 28)
                .padding(.horizontal, 18)

                HStack {
                    pointsChip
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.horizontal, 18)

                Spacer()
            }


                    // 3) UNTERER BEREICH: Trophy mittig, Profil rechts
                    trophyRoadButton
                    profileButton
                }
        .overlay(playerPopupOverlay)
        .overlay(challengeDialogOverlay)
        .overlay(incomingChallengeOverlay)
        .overlay(outgoingChallengeOverlay)
        .overlay(resultPendingOverlay)
        .overlay(alignment: .top) { mapBannerOverlay }
        .sheet(isPresented: $showChallengeView) {
            challengeSheet
        }
        .sheet(isPresented: $showSettings) {
            if let auth {
                SettingsView(auth: auth)
            } else {
                // Fallback for previews / default init
                Text("Einstellungen sind erst nach dem Login verfügbar")
                    .padding()
            }
        }
        .sheet(isPresented: $showShop) {
            ShopView(
                ownPlayerId: ownPlayerId,
                initialPoints: ownPoints,
                onPointsChanged: { newPoints in
                    ownPoints = newPoints
                }
            )
        }
        .onChange(of: showShop) { isShown in
            if isShown {
                reloadOwnPlayerData()
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileContainerView(
                ownPlayerId: ownPlayerId,
                data: UserProfileData(
                    name: ownPlayerName,
                    avatarImageName: AvatarPresets.persistedImageName(),
                    rankName: ownRankName,
                    dailyStreak: ownDailyStreak,
                    totalChallenges: ownTotalChallenges,
                    wonChallenges: ownWonChallenges,
                    points: ownPoints
                ),
                pointsHistory: pointsHistory,
                battleHistory: battleHistory,
                profileStatusText: profileStatusText,
                profileBadges: profileBadges,
                rankColor: rankColor(for: ownRankName),
                allChallenges: allChallenges,
                socket: socket,
                currentCoordinate: ownCoordinate
            )
        }
        .onChange(of: showProfile) { isShown in
            if isShown {
                reloadOwnPlayerData()
            }
        }




        
        .fullScreenCover(isPresented: .constant(activeFullScreen != .none)) {
            // Debug: print active battle info so we can see which challenge name arrives
            if activeFullScreen == .battle {
                if let info = activeBattleInfo {
                    // Use an EmptyView with onAppear to perform side effects inside a ViewBuilder
                    EmptyView().onAppear {
                        print("DEBUG: activeBattleInfo category=\(info.category) name=\(info.challengeName)")
                    }
                } else {
                    EmptyView().onAppear {
                        print("DEBUG: activeFullScreen==.battle but activeBattleInfo is nil")
                    }
                }
            }

            switch activeFullScreen {
            case .battle:
                if let info = activeBattleInfo,
                   let battleId = currentBattleId {

                    switch BattleScreen.forChallenge(category: info.category, name: info.challengeName) {
                    case .knowledge:
                        KnowledgeBattleView(
                            battleId: battleId,
                            socket: socket,
                            initialQuestion: lastKnowledgeQuestion,
                            onClose: { activeFullScreen = .none }
                        )

                    case .checkInSpot:
                        if let target = currentTargetCoordinate {
                            CheckInSpotView(
                                battleId: battleId,
                                playerId: ownPlayerId,
                                playerName: ownPlayerName,
                                socket: socket,
                                targetCoordinate: target,
                                radius: 30,
                                onClose: {
                                    activeFullScreen = .none
                                }
                            )
                        } else {
                            // Kein Zielpunkt vom Backend → normales Battle
                            genericBattleView(info: info)
                        }

                    case .sprint:
                        SprintChallengeView(
                            battleId: battleId,
                            playerId: ownPlayerId,
                            playerName: ownPlayerName,
                            socket: socket,
                            onClose: { activeFullScreen = .none }
                        )

                    case .loudness:
                        LoudnessChallengeView(
                            battleId: battleId,
                            playerId: ownPlayerId,
                            socket: socket,
                            onClose: { activeFullScreen = .none }
                        )

                    case .camera:
                        CameraChallengeView(
                            battleId: battleId,
                            socket: socket,
                            onClose: { activeFullScreen = .none }
                        )

                    case .compass:
                        CompassChallengeView(battleId: battleId, playerId: ownPlayerId, socket: socket, onClose: { activeFullScreen = .none })

                    case .shake:
                        ShakeChallengeView(
                            battleId: battleId,
                            socket: socket,
                            onClose: { activeFullScreen = .none }
                        )

                    case .pushup:
                        PushupChallengeView(
                            battleId: battleId,
                            socket: socket,
                            onClose: { activeFullScreen = .none }
                        )

                    case .generic:
                        genericBattleView(info: info)
                    }

                } else {
                    EmptyView()
                }





            case .win:
                if let data = resultData {
                    BattleWinView(data: data, ownPlayerName: ownPlayerName) {
                        activeFullScreen = .none   // zurück zur Map
                    }
                } else {
                    EmptyView()
                }


            case .lose:
                if let data = resultData {
                    BattleLoseView(data: data, ownPlayerName: ownPlayerName) {
                        activeFullScreen = .none   // schließt das Fullscreen-Cover
                    }
                } else {
                    EmptyView()
                }
            case .voting:
                if let info = activeBattleInfo,
                   let battleId = currentBattleId {
                    BattleVotingView(
                        playerA: info.playerA,  // nur Name
                        playerB: info.playerB   // nur Name
                    ) { side in
                        // playerA = ich, playerB = Gegner
                        let winner = side.winner(
                            ownId: ownPlayerId, ownName: info.playerA,
                            opponentId: info.opponentId, opponentName: info.playerB
                        )
                        myVote = winner.name
                        socket.sendVote(
                            battleId: battleId,
                            winnerId: winner.id,
                            winnerName: winner.name
                        )
                        activeFullScreen = .none
                        activeOverlay = .resultPending
                    }
                } else {
                    EmptyView()
                }





            case .none:
                EmptyView()
            }
        }


    }


    
    // MARK: - Map & Controls
    
    /// Main map layer with annotations, camera bounds and appearance.
    private var mapLayer: some View {
        Map(
            position: $position,
            bounds: MapCameraBounds(
                minimumDistance: minDistance,
                maximumDistance: maxDistance
            )
        ) {
            /// 200m radius around ownplayer
            if let ownCoordinate {
                MapCircle(center: ownCoordinate, radius: 200)
                    .foregroundStyle(Color.blue.opacity(0.2))
                    .stroke(Color.blue.opacity(0.6), lineWidth: 2)

                Annotation("Du", coordinate: ownCoordinate) {
                    MapAvatarPin(
                        imageName: AvatarPresets.persistedImageName(),
                        ringColor: .challengrYellow,
                        isOwnPlayer: true
                    )
                }
            }

            // Annotations for all nearby players.
            ForEach(annotations) { annotation in
                Annotation(annotation.title, coordinate: annotation.coordinate) {
                    Button {
                        if selectedPlayer?.id == annotation.id {
                            showPlayerPopup.toggle()
                        } else {
                            selectedPlayer = annotation
                            showPlayerPopup = true
                        }
                    } label: {
                        MapAvatarPin(
                            imageName: nil,
                            ringColor: rankColor(for: annotation.rankName),
                            isOwnPlayer: false
                        )
                    }
                }
            }
        }
        .mapStyle(
            .standard(
                elevation: .realistic,
                pointsOfInterest: .excludingAll,
                showsTraffic: false
            )
        )
        .tint(.challengrGreen)
        .accentColor(.challengrYellow)
        .ignoresSafeArea()
        .onAppear {
            setupSocket()
            seedInitialZoom()
            friendsInbox.start(playerId: ownPlayerId)
            NotificationManager.shared.requestAuthorizationIfNeeded()

            // Start lightweight polling for nearby players.
            if nearbyRefreshTask == nil {
                nearbyRefreshTask = Task {
                    while !Task.isCancelled {
                        if let loc = ownCoordinate {
                            await refreshNearbyPlayers(at: loc)
                        }
                        try? await Task.sleep(nanoseconds: 4_000_000_000) // 4s
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                // Keep the socket alive a bit so late challenges still arrive.
                NotificationManager.shared.beginBackgroundWindow()
            case .active:
                NotificationManager.shared.endBackgroundWindow()
                Task { await friendsInbox.refreshCount() }
            default:
                break
            }
        }
        .onChange(of: friendsInbox.lastBannerText) { _, newValue in
            guard let text = newValue, !text.isEmpty else { return }
            showMapBanner(icon: "person.badge.plus", text: text)
            friendsInbox.consumeBanner()
        }
        .onDisappear {
            friendsInbox.stop()
            nearbyRefreshTask?.cancel()
            nearbyRefreshTask = nil
        }
        /// React to location updates
        .onReceive(locationHelper.$userLocation, perform: handleLocation)
        .onMapCameraChange { ctx in
                let heading = ctx.camera.heading    // 0 = Norden
                compassAngle = .degrees(heading)
                if !isProgrammaticCameraUpdate {
                    currentZoomDistance = ctx.camera.distance
                    if !hasCapturedInitialZoom {
                        hasCapturedInitialZoom = true
                    }
                    if let ownCoordinate {
                        let center = ctx.camera.centerCoordinate
                        let deltaLat = abs(center.latitude - ownCoordinate.latitude)
                        let deltaLon = abs(center.longitude - ownCoordinate.longitude)
                        if deltaLat > 0.00025 || deltaLon > 0.00025 {
                            isFollowingUser = false
                        }
                    }
                }
            }
    }

    /// Always-visible points/currency chip, tappable to jump straight into the shop.
    private var pointsChip: some View {
        Button {
            showShop = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.challengrYellow)
                Text("\(ownPoints)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.challengrDark)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    /// Floating button that centers the map on the current user location.
    private var locationButton: some View {
        LocationButton(.currentLocation) {
            position = .userLocation(
                followsHeading: false,
                fallback: .camera(
                    MapCamera(
                        centerCoordinate: startCoordinate,
                        distance: 1000,
                        heading: 0,
                        pitch: 0
                    )
                )
            )
        }
        .labelStyle(.iconOnly)
        .symbolVariant(.fill)
        .tint(.blue)
        .cornerRadius(12)
        .padding()
    }

    /// Trophy button at the bottom that opens the global ChallengeView.
    private var trophyRoadButton: some View {
        VStack {
            Spacer()
            Button {
                showTrophyRoad = true
            } label: {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.challengrDark)
                    .frame(width: 64, height: 64)
                    .background(Color.challengrYellow)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            }
            .sheet(isPresented: $showTrophyRoad) {
                TrophyRoadView(playerId: ownPlayerId)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
    }


    
    // Profil
    private var profileButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    reloadOwnPlayerData()
                    showProfile = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(AvatarPresets.persistedImageName())
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 3)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

                        if friendsInbox.pendingIncomingCount > 0 {
                            Text("\(friendsInbox.pendingIncomingCount)")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.challengrRed))
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                .padding(.bottom, 32)
                .padding(.trailing, 20)
            }
        }
    }



    
    
    
    
    // MARK: - Overlays

    /// Small popup above a selected player on the map.
    private var playerPopupOverlay: some View {
        Group {
            if let player = selectedPlayer, showPlayerPopup {
                VStack(spacing: 10) {

                    MapAvatarPin(
                        imageName: nil,
                        ringColor: rankColor(for: player.rankName),
                        isOwnPlayer: false
                    )

                    VStack(spacing: 2) {
                        Text(cleanPlayerName(player.title).uppercased())
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.challengrBlack)

                        Text(player.rankName.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(rankColor(for: player.rankName))
                    }

                    Button {
                        showPlayerChallengeDialog = true
                    } label: {
                        Text("HERAUSFORDERN")
                            .font(.system(size: 13, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.challengrBlack)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.challengrYellow)
                            )
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(radius: 15)
                .padding(.top, 80)
                .transition(.scale)
            }
        }
    }


    /// Fullscreen  overlay that hosts the ChallengeDialogView.
    private var challengeDialogOverlay: some View {
        Group {
            if let player = selectedPlayer, showPlayerChallengeDialog {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showPlayerChallengeDialog = false
                        }

                    ChallengeDialogView(
                        otherPlayerId: player.playerId,
                        otherPlayerName: cleanPlayerName(player.title),
                        otherPlayerRankColor: rankColor(for: player.rankName),
                        ownPlayerId: ownPlayerId,
                        allChallenges: allChallenges,
                        socket: socket
                    ) {
                        showPlayerChallengeDialog = false
                    }
                }
                .transition(.scale)
            }
        }
    }

    /// Small circular category badge (icon + tint), used in challenge overlays.
    private func categoryBadge(for category: String) -> some View {
        ZStack {
            Circle()
                .fill(categoryColor(for: category).opacity(0.16))
                .frame(width: 40, height: 40)

            Image(systemName: categoryIcon(for: category))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(categoryColor(for: category))
        }
    }

    private func categoryColor(for category: String) -> Color {
        switch category {
        case "Fitness":  return .challengrYellow
        case "Mutprobe": return .chalengrRed
        case "Wissen":   return .challengrGreen
        case "iPhone":   return .challengrBlack
        case "Customer": return .gray
        default:         return .challengrYellow
        }
    }

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Fitness":  return "sportscourt"
        case "Mutprobe": return "flame"
        case "Wissen":   return "lightbulb"
        case "iPhone":   return "iphone"
        case "Customer": return "person.2"
        default:         return "questionmark"
        }
    }

    /// Overlay that appears when another player challenges the local player.
    private var incomingChallengeOverlay: some View {
        Group {
            if let challenge = incomingChallenge {
                let battleId = challenge.battleId
                let opponentAnnotation = annotations.first(where: { $0.playerId == challenge.fromId })
                let opponentTitle = opponentAnnotation?.title ?? "Gegner \(challenge.fromId)"
                let opponentName = cleanPlayerName(opponentTitle)
                let opponentRingColor = opponentAnnotation.map { rankColor(for: $0.rankName) } ?? .gray

                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()

                    GameCard {
                        Text("CHALLENGE!")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(1.4)
                            .foregroundColor(.challengrYellow)

                        MapAvatarPin(imageName: nil, ringColor: opponentRingColor, isOwnPlayer: false)

                        Text(opponentName.uppercased())
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.challengrDark)

                        categoryBadge(for: challenge.category)

                        Text(challenge.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.challengrDark)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.challengrYellow)
                            )

                        HStack(spacing: 14) {
                            GamePrimaryButton(title: "Annehmen", color: .challengrGreen) {
                                socket.sendUpdateBattleStatus(
                                    battleId: battleId,
                                    status: "ACCEPTED"
                                )

                                activeBattleInfo = (
                                    challengeName: challenge.name,
                                    category: challenge.category,
                                    playerA: ownPlayerName,
                                    playerB: opponentName,
                                    opponentId: challenge.fromId
                                )

                                currentBattleId = battleId
                                incomingChallenge = nil
                                activeFullScreen = .battle
                            }

                            GamePrimaryButton(title: "Ablehnen", color: .challengrSurface) {
                                socket.sendUpdateBattleStatus(
                                    battleId: battleId,
                                    status: "DECLINED"
                                )
                                SoundManager.shared.play(.challengeClosed)

                                incomingChallenge = nil
                            }
                            .foregroundColor(.challengrRed)
                        }
                    }
                    .frame(maxWidth: 320)
                }

                .transition(.scale)
            }
        }
    }

    /// Overlay shown for the attacker while the request is pending.
    private var outgoingChallengeOverlay: some View {
        Group {
            if incomingChallenge == nil,
               let outgoing = outgoingBattleInfo,
               activeFullScreen == .none {

                let outgoingAnnotation = annotations.first(where: { $0.playerId == outgoing.opponentId })
                let opponentTitle = outgoingAnnotation?.title ?? "Gegner \(outgoing.opponentId)"
                let opponentName = cleanPlayerName(opponentTitle)
                let outgoingRingColor = outgoingAnnotation.map { rankColor(for: $0.rankName) } ?? .gray

                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    GameCard {
                        Text("ANFRAGE GESENDET")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(.challengrYellow)

                        MapAvatarPin(imageName: nil, ringColor: outgoingRingColor, isOwnPlayer: false)

                        Text(opponentName.uppercased())
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.challengrDark)

                        Text(outgoing.challengeName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.challengrDark)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.challengrYellow)
                            )

                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(.challengrDark)

                            Text("Warte auf Annahme …")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.challengrDark)
                        }

                        GamePrimaryButton(title: "Abbrechen", color: .challengrSurface) {
                            // Tell the backend, so the receiver's popup disappears too.
                            socket.sendUpdateBattleStatus(battleId: outgoing.battleId, status: "CANCELLED")
                            SoundManager.shared.play(.challengeClosed)
                            outgoingBattleInfo = nil
                        }
                        .foregroundColor(.challengrRed)
                    }
                    .frame(maxWidth: 320)
                }
                .transition(.opacity)
            }
        }
    }

    /// Normal battle (Timer + Voting) – used for all non-special challenges.
    @ViewBuilder
    private func genericBattleView(info: (challengeName: String, category: String, playerA: String, playerB: String, opponentId: String)) -> some View {
        BattleView(
            challengeName: info.challengeName,
            category: info.category,
            playerLeft: info.playerA,
            playerRight: info.playerB,
            onClose: {
                activeFullScreen = .none
            },
            onSurrender: {
                if let battleId = currentBattleId {
                    socket.sendUpdateBattleStatus(
                        battleId: battleId,
                        status: "DONE_SURRENDER"
                    )
                }
                activeFullScreen = .none
                activeOverlay = .resultPending
            },
            onFinished: {
                if let battleId = currentBattleId {
                    socket.sendUpdateBattleStatus(
                        battleId: battleId,
                        status: "READY_FOR_VOTING"
                    )
                }
            }
        )
    }

    private var mapBannerOverlay: some View {
        Group {
            if let banner = mapBanner {
                MapInfoBanner(icon: banner.icon, text: banner.text)
                    .padding(.top, 90)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func showMapBanner(icon: String, text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            mapBanner = (icon: icon, text: text)
        }
        mapBannerHideTask?.cancel()
        mapBannerHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                mapBanner = nil
            }
        }
    }

    private var resultPendingOverlay: some View {
        Group {
            if activeOverlay == .resultPending {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()

                    ResultPendingCard()
                }
                .transition(.opacity)
            }
        }
    }

    
    // MARK: - Sheets & Screens

    /// Bottom sheet that shows the full challenge list.
    private var challengeSheet: some View {
        ChallengeView()
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
    }

    /// Fullscreen battle screen displayed after accepting a challenge.
    private var battleScreen: some View {
        Group {
            if let info = activeBattleInfo,
               let battleId = currentBattleId {
                BattleView(
                    challengeName: info.challengeName,
                    category: info.category,
                    playerLeft: info.playerA,
                    playerRight: info.playerB,
                    onClose: {
                        activeFullScreen = .none
                    },
                    onSurrender: {
                        socket.sendUpdateBattleStatus(
                            battleId: battleId,
                            status: "DONE_SURRENDER"
                        )
                        // optional: socket.sendVote(battleId: battleId, winnerName: info.playerB)
                        activeFullScreen = .none
                    },
                    onFinished: {
                            // NEU: statt direkt Voting öffnen
                            if let battleId = currentBattleId {
                                socket.sendUpdateBattleStatus(
                                    battleId: battleId,
                                    status: "READY_FOR_VOTING"
                                )
                            }
                        }
                    
                )
            } else {
                EmptyView()
            }
        }
    }






    // MARK: - Data loading & flow (Daten laden & Ablauf)

    /// Reloads profile-related data for the current player (Profildaten neu laden)
    private func reloadOwnPlayerData() {
        Task {
            do {
                let me = try await playerService.loadPlayerById(id: ownPlayerId)
                let name = me.name
                let rank = me.rankName

                async let pointsAsync = playerService.loadPlayerPoints(id: ownPlayerId)
                async let streakAsync = playerService.loadPlayerStreak(id: ownPlayerId)
                async let statsAsync  = playerService.loadPlayerStats(id: ownPlayerId)
                async let historyAsync = playerService.loadPlayerPointsHistory(id: ownPlayerId)
                async let battlesAsync = playerService.loadPlayerBattles(id: ownPlayerId)
                async let profileAsync = playerService.loadPlayerProfile(id: ownPlayerId)

                let points = try await pointsAsync
                let streak = try await streakAsync
                let stats  = try await statsAsync
                let history = (try? await historyAsync) ?? []
                let battles = (try? await battlesAsync) ?? []
                let profile = (try? await profileAsync) ?? PlayerProfileDTO(status: nil, badges: [])

                await MainActor.run {
                    ownPlayerName      = name
                    ownRankName        = rank
                    ownPoints          = points
                    ownDailyStreak     = streak
                    ownTotalChallenges = stats.totalChallenges
                    ownWonChallenges   = stats.wonChallenges
                    pointsHistory      = history
                    battleHistory      = battles
                    profileStatusText  = profile.status
                    profileBadges      = profile.badges
                }
            } catch {
                print("Fehler beim Reload der eigenen Daten:", error)
            }
        }
    }


    /// Sets up WebSocket and preloads challenges (WebSocket starten & Challenges vorladen)
    private func setupSocket() {
        socket.connect()

        // Preload challenges for all categories once at startup.
        Task {
            await preloadChallenges()
        }

        Task {
            await loadRankColors()
        }



        reloadOwnPlayerData()



        socket.onChallengeReceived = { battleId, fromId, toId, challengeId, challengeText, challengeCategory, targetLat, targetLon in
            let route = ChallengeRouter.route(fromId: fromId, toId: toId,
                                              ownPlayerId: ownPlayerId, isInBattle: isInBattle)
            switch route {
            case .ignore:
                return
            case .declineBusy:
                // Mitten im Battle: neue Anfrage nicht übernehmen, sonst hängt das laufende Battle.
                print("Anfrage \(battleId) abgelehnt – wir sind gerade im Battle")
                socket.sendUpdateBattleStatus(battleId: battleId, status: "DECLINED")
                return
            case .incoming:
                latestIncomingRequestId = battleId
            case .outgoing:
                latestOutgoingRequestId = battleId
            }

            Task { @MainActor in
                let info = await resolveChallengeInfo(
                    id: challengeId,
                    text: challengeText,
                    category: challengeCategory
                )
                // A newer request arrived while we were resolving -> drop this one.
                let latest = route == .incoming ? latestIncomingRequestId : latestOutgoingRequestId
                guard latest == battleId else { return }
                // Battle started meanwhile (z.B. anderes Popup angenommen) -> nicht mehr anzeigen.
                if route == .incoming, isInBattle {
                    socket.sendUpdateBattleStatus(battleId: battleId, status: "DECLINED")
                    return
                }

                // Backend re-sends open requests after a reconnect – only alert once.
                let alreadyShown = incomingChallenge?.battleId == battleId
                if toId == ownPlayerId, !alreadyShown {
                    SoundManager.shared.play(.challengeIncoming)
                    NotificationManager.shared.notifyIfInBackground(
                        title: "Neue Challenge!",
                        body: info.name,
                        identifier: "battle-\(battleId)"
                    )
                }

                // currentBattleId wird erst gesetzt, wenn das Battle wirklich startet –
                // sonst könnte eine neue Anfrage ein laufendes Battle "kapern".
                if route == .incoming {
                    incomingChallenge = (
                        battleId: battleId,
                        fromId: fromId,
                        challengeId: challengeId,
                        name: info.name,
                        category: info.category
                    )
                } else {
                    // Wir sind der Angreifer (auch nach einem Neustart vom Server nachgeliefert)
                    outgoingBattleInfo = (
                        battleId: battleId,
                        opponentId: toId,
                        challengeName: info.name,
                        category: info.category
                    )
                }

                if info.category != "Wissen" {
                    lastKnowledgeQuestion = nil
                }

                // Zielkoordinate (für Check-In-Spot)
                if let lat = targetLat, let lon = targetLon {
                    currentTargetCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                } else {
                    currentTargetCoordinate = nil
                }
            }
        }

        // Nach einem Neustart mitten im Battle: Battle-Screen wiederherstellen (BUG-06).
        socket.onBattleRunning = { battleId, fromId, toId, challengeId, challengeText, challengeCategory, status in
            guard fromId == ownPlayerId || toId == ownPlayerId else { return }
            // Kurzer Verbindungsabbruch im Battle-Screen → alles bleibt, wie es ist
            guard !isInBattle, activeFullScreen == .none else { return }
            // Sofort setzen, damit eine gleich folgende Wissensfrage zugeordnet werden kann
            currentBattleId = battleId

            Task { @MainActor in
                let info = await resolveChallengeInfo(id: challengeId, text: challengeText, category: challengeCategory)
                guard currentBattleId == battleId, !isInBattle, activeFullScreen == .none else { return }

                let opponentId = fromId == ownPlayerId ? toId : fromId
                let opponentTitle = annotations.first(where: { $0.playerId == opponentId })?.title ?? "Gegner \(opponentId)"
                incomingChallenge = nil
                outgoingBattleInfo = nil
                activeBattleInfo = (
                    challengeName: info.name,
                    category: info.category,
                    playerA: ownPlayerName,
                    playerB: cleanPlayerName(opponentTitle),
                    opponentId: opponentId
                )
                activeFullScreen = status == "READY_FOR_VOTING" ? .voting : .battle
            }
        }

        // Realtime: when any player moves, update the nearby list quickly (but throttled).
        socket.onPlayerPositionUpdated = { _, _, _ in
            // Only refresh when we actually know our own location.
            Task { await scheduleNearbyRefreshFromWebSocket() }
        }


        
        socket.onBattleAccepted = { battleId in
            
            print("🔥 onBattleAccepted: battleId:", battleId,
                      "currentBattleId:", currentBattleId as Any,
                      "incomingChallenge:", incomingChallenge as Any,
                      "outgoingBattleInfo:", outgoingBattleInfo as Any)
            // Muss eine unserer offenen Anfragen sein
            let accepted = ChallengeRouter.acceptedRequest(battleId: battleId,
                                                           incomingId: incomingChallenge?.battleId,
                                                           outgoingId: outgoingBattleInfo?.battleId)
            guard accepted != .ignore else { return }
            currentBattleId = battleId

            // Fall A: Wir wurden herausgefordert
            if accepted == .incoming, let challenge = incomingChallenge {
                let opponentTitle =
                    annotations.first(where: { $0.playerId == challenge.fromId })?.title
                    ?? "Gegner \(challenge.fromId)"

                let opponentName = cleanPlayerName(opponentTitle)

                activeBattleInfo = (
                    challengeName: challenge.name,
                    category: challenge.category,
                    playerA: ownPlayerName,   // schon ohne Rank
                    playerB: opponentName,    // jetzt auch ohne Rank
                    opponentId: challenge.fromId
                )

                incomingChallenge = nil
                activeFullScreen = .battle
                return
            }


            // Fall B: Wir sind der Angreifer
            if accepted == .outgoing, let outgoing = outgoingBattleInfo {
                let opponentTitle =
                    annotations.first(where: { $0.playerId == outgoing.opponentId })?.title
                    ?? "Gegner \(outgoing.opponentId)"

                let opponentName = cleanPlayerName(opponentTitle)

                activeBattleInfo = (
                    challengeName: outgoing.challengeName,
                    category: outgoing.category,
                    playerA: ownPlayerName,
                    playerB: opponentName,
                    opponentId: outgoing.opponentId
                )

                SoundManager.shared.play(.challengeAccepted)
                outgoingBattleInfo = nil
                activeFullScreen = .battle
                return
            }

        }


    
        
        socket.onBattleResult = { data in
            // Only results of our own battle (Ergebnisse fremder Battles ignorieren)
            guard data.isRelevant(ownPlayerId: ownPlayerId, currentBattleId: currentBattleId) else { return }

            // NEU: Punkte/Streak nach Battle neu laden
            reloadOwnPlayerData()

            resultData = data
            activeFullScreen = .none

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                activeOverlay = .none
                if data.didWin(ownPlayerId: ownPlayerId, ownPlayerName: ownPlayerName) {
                    activeFullScreen = .win
                } else {
                    activeFullScreen = .lose
                }
            }
        }

        
        socket.onBattleRejected = { reason in
            SoundManager.shared.play(.challengeClosed)
            showMapBanner(icon: "exclamationmark.triangle.fill", text: reason)
        }

        socket.onReadyForVoting = { battleId in
            currentBattleId = battleId
            activeFullScreen = .voting   // beide springen in Voting-Screen
        }
        
        socket.onBattlePending = { battleId in
            print("🟡 onBattlePending für Battle", battleId)
            currentBattleId = battleId
            activeOverlay = .resultPending
        }

        
        socket.onFriendRequestCreated = { _, fromId, toId in
            friendsInbox.handleRequestCreated(fromId: fromId, toId: toId)
        }

        socket.onFriendRequestUpdated = { _, fromId, toId, status in
            friendsInbox.handleRequestUpdated(fromId: fromId, toId: toId, status: status)
        }

        socket.onBattleUpdatedStatus = { battleId, status in
            print("Battle \(battleId) status updated to \(status)")
            handleBattleClosed(battleId: battleId, status: status)
        }
        
        socket.onKnowledgeQuestion = { battleId, challenge, timeLimit in
            print("📩 Knowledge question erhalten:", battleId, challenge.text)

            guard battleId == currentBattleId else { return }

            let payload = (
                battleId: battleId,
                text: challenge.text,
                choices: challenge.choices ?? [],
                timeLimit: timeLimit
            )

            // 1) State merken
            lastKnowledgeQuestion = payload

            // 2) Notification feuern (für bereits offenen View)
            NotificationCenter.default.post(
                name: .knowledgeQuestionReceived,
                object: nil,
                userInfo: [
                    "battleId": battleId,
                    "text": payload.text,
                    "choices": payload.choices,
                    "timeLimit": payload.timeLimit as Any
                ]
            )
        }

        socket.onKnowledgeAnswerFeedback = { battleId, correct in
            guard battleId == currentBattleId else { return }
            NotificationCenter.default.post(
                name: .knowledgeAnswerFeedback,
                object: nil,
                userInfo: ["battleId": battleId, "correct": correct]
            )
        }



    }

    /// Mitten in einem angenommenen Battle (inkl. Voting und "Ergebnis wird berechnet").
    /// Bewusst nicht über activeBattleInfo: das bleibt nach dem Ergebnis gesetzt.
    private var isInBattle: Bool {
        activeFullScreen == .battle || activeFullScreen == .voting || activeOverlay == .resultPending
    }

    @MainActor
    private func loadRankColors() async {
        do {
            let ranks = try await rankService.loadRanks()
            rankColorsByName = Dictionary(uniqueKeysWithValues: ranks.map { ($0.name, $0.uiColor) })
        } catch {
            print("Fehler beim Laden der Rank-Farben:", error)
        }
    }

    private func rankColor(for rankName: String) -> Color {
        // Backend returns "Unranked" for players whose points fall outside every
        // configured rank range (e.g. after dropping below 0). Give that a neutral
        // color instead of silently reusing red, which already belongs to two
        // real ranks (Punchbag, Brawler) and would otherwise read as a random
        // rank rather than "no rank data".
        rankColorsByName[rankName] ?? .gray
    }

    @MainActor
    /// A request ended before the battle started (abgelehnt / abgebrochen / abgelaufen).
    private func handleBattleClosed(battleId: Int64, status: String) {
        // Laufendes Battle ohne Fortschritt vom Backend abgebrochen (keine Punkte)
        if status == "ABANDONED" {
            guard currentBattleId == battleId else { return }
            activeFullScreen = .none
            activeOverlay = .none
            activeBattleInfo = nil
            currentBattleId = nil
            SoundManager.shared.play(.challengeClosed)
            showMapBanner(icon: "clock.badge.xmark", text: "Battle abgebrochen – zu lange keine Aktion, keine Punkte")
            return
        }

        let closedStatuses = ["DECLINED", "CANCELLED", "EXPIRED"]
        guard closedStatuses.contains(status) else { return }

        NotificationManager.shared.removeNotification(identifier: "battle-\(battleId)")

        if let incoming = incomingChallenge, incoming.battleId == battleId {
            withAnimation { incomingChallenge = nil }
            if currentBattleId == battleId { currentBattleId = nil }
            if status == "CANCELLED" {
                SoundManager.shared.play(.challengeClosed)
                showMapBanner(icon: "xmark.circle.fill", text: "Challenge wurde zurückgezogen")
            } else if status == "EXPIRED" {
                showMapBanner(icon: "clock.badge.xmark", text: "Challenge ist abgelaufen")
            }
            return
        }

        if let outgoing = outgoingBattleInfo, outgoing.battleId == battleId {
            withAnimation { outgoingBattleInfo = nil }
            if currentBattleId == battleId { currentBattleId = nil }
            SoundManager.shared.play(.challengeClosed)
            switch status {
            case "DECLINED": showMapBanner(icon: "hand.raised.fill", text: "Challenge wurde abgelehnt")
            case "EXPIRED":  showMapBanner(icon: "clock.badge.xmark", text: "Keine Antwort – Challenge abgelaufen")
            default: break
            }
        }
    }

    private func preloadChallenges() async {
        let categories = ["Fitness", "Mutprobe", "Wissen", "iPhone", "Customer"]
        var loadedChallenges: [ChallengeDTO] = []

        for category in categories {
            do {
                let challenges = try await challengesService.loadCategoryChallenges(category: category)
                loadedChallenges.append(contentsOf: challenges)
            } catch {
                print("Fehler beim Laden der Kategorie \(category):", error)
            }
        }

        allChallenges = loadedChallenges
        print("AllChallenges geladen, Anzahl:", allChallenges.count)
    }

    private func scheduleNearbyRefreshFromWebSocket() async {
        let now = Date()
        if let last = lastWsNearbyRefreshAt, now.timeIntervalSince(last) < 2.0 {
            return
        }
        lastWsNearbyRefreshAt = now

        wsNearbyRefreshTask?.cancel()
        wsNearbyRefreshTask = Task {
            // Debounce bursts of WS events
            try? await Task.sleep(nanoseconds: 350_000_000) // 0.35s
            guard !Task.isCancelled else { return }
            if let loc = ownCoordinate {
                await refreshNearbyPlayers(at: loc)
            }
        }
    }

    /// Handles updates of the user location and refreshes nearby players.
    private func handleLocation(_ userLoc: CLLocationCoordinate2D?) {
        guard let userLoc = userLoc else { return }

        /// Make the camera follow the player.
        ownCoordinate = userLoc
        if !hasCenteredOnUser {
            hasCenteredOnUser = true
            isFollowingUser = true
        }

        guard isFollowingUser else { return }
        guard hasCapturedInitialZoom else { return }

        let currentCamera = position.camera
        let heading = currentCamera?.heading ?? 0
        let pitch = currentCamera?.pitch ?? 0
        if let distance = currentCamera?.distance {
            currentZoomDistance = distance
        }

        isProgrammaticCameraUpdate = true
        position = .camera(
            MapCamera(
                centerCoordinate: userLoc,
                distance: currentZoomDistance,
                heading: heading,
                pitch: pitch
            )
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isProgrammaticCameraUpdate = false
        }

        Task { await refreshNearbyPlayers(at: userLoc) }
    }

    @MainActor
    private func refreshNearbyPlayers(at coordinate: CLLocationCoordinate2D) async {
        do {
            let players = try await playerService.loadNearbyPlayers(
                currentPlayerId: ownPlayerId,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radius: 200.0
            )

            annotations = players.map {
                PlayerAnnotation(
                    playerId: $0.id,
                    coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                    title: "\($0.name) · \($0.rankName)",
                    rankName: $0.rankName
                )
            }

            if let me = players.first(where: { $0.id == ownPlayerId }) {
                ownPlayerName = me.name
            }
        } catch {
            print("Fehler beim Laden der Nearby Players", error)
        }
    }

    private func seedInitialZoom() {
        guard !hasCapturedInitialZoom else { return }
        if let distance = position.camera?.distance {
            currentZoomDistance = distance
            hasCapturedInitialZoom = true
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard !hasCapturedInitialZoom else { return }
            if let distance = position.camera?.distance {
                currentZoomDistance = distance
                hasCapturedInitialZoom = true
            }
        }
    }

    private func cleanPlayerName(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = " · "
        if trimmed.contains(separator) {
            return trimmed.components(separatedBy: separator).first ?? trimmed
        }
        return trimmed
    }
}

private struct MapInfoBanner: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(.challengrDark)

            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.challengrDark)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.challengrYellow)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}
