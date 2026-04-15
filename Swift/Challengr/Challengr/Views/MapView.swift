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
}

// MARK: - Models (Modelle)

/// Simple model to represent a player as a map annotation.
struct PlayerAnnotation: Identifiable {
    let id = UUID()
    let playerId: Int64
    let coordinate: CLLocationCoordinate2D
    let title: String
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

    let ownPlayerId: Int64
    let auth: KeycloakAuthService

    @StateObject private var locationHelper: LocationHelper

    private let playerService = PlayerLocationService()
    private let challengesService = ChallengesService()

    @State private var allChallenges: [ChallengeDTO] = []

    /// WebSocket
    @StateObject private var socket: GameSocketService

    
    /// Information about an incoming challenge from another player.
    @State private var incomingChallenge: (
        battleId: Int64,
        fromId: Int64,
        challengeId: Int64,
        name: String,
        category: String
    )? = nil
    
    @State private var outgoingBattleInfo: (
        battleId: Int64,
        opponentId: Int64,
        challengeName: String,
        category: String
    )? = nil


    /// Battle Infos and Settings.
    @State private var currentBattleId: Int64? = nil
    @State private var activeBattleInfo: (challengeName: String,
                                          category: String,
                                          playerA: String,
                                          playerB: String)? = nil
    @State private var activeFullScreen: ActiveFullScreen = .none
    @State private var resultData: BattleResultData? = nil

    /// Static ownPlayerName & coordinates
    @State var ownPlayerName: String
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
    @State private var currentTargetCoordinate: CLLocationCoordinate2D? = nil

    
    @State private var lastKnowledgeQuestion: (battleId: Int64, text: String, choices: [String])?


    /// Fallback (Default Map: Vienna)
    private let startCoordinate = CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738)

    
    /// Current map camera position and Zoom
    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
            distance: 1000,
            heading: 0,
            pitch: 0
        )
    )

    // MARK: - Init
    init(ownPlayerId: Int64, ownPlayerName: String, auth: KeycloakAuthService) {
        self.ownPlayerId = ownPlayerId
        self.auth = auth
        _ownPlayerName = State(initialValue: ownPlayerName)
        _socket = StateObject(wrappedValue: GameSocketService(playerId: ownPlayerId))
        _locationHelper = StateObject(wrappedValue: LocationHelper(playerId: ownPlayerId, playerName: ownPlayerName))
    }
    
    @State private var myVote: String? = nil
    @State private var opponentVote: String? = nil

    @State private var activeOverlay: ActiveOverlay = .none

    let minDistance: CLLocationDistance = 200
    let maxDistance: CLLocationDistance = 5000

    
    /// All players that should be displayed
    @State private var annotations: [PlayerAnnotation] = []
    
    /// Challenge Infos Window
    @State private var showChallengeView = false
    @State private var showTrophyRoad = false

    /// Player Selected Infos
    @State private var selectedPlayer: PlayerAnnotation? = nil
    @State private var showPlayerPopup = false
    @State private var showPlayerChallengeDialog = false

    @State private var showNearbyText = true

    
    /// Resolves a challenge text + category for a given ID (Challenge-Infos für ID)
    private func challengeInfo(for id: Int64) -> (name: String, category: String) {
        if let ch = allChallenges.first(where: { $0.id == id }) {
            return (ch.text, ch.category)
        } else {
            return ("Challenge \(id)", "Unbekannt")
        }
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
                            // TODO: Settings öffnen
                        } label: {
                            HudCircleButton(systemName: "gearshape.fill")
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


                Spacer()
            }

            // UNTERER BEREICH: Trophy mittig, Profil rechts
            trophyRoadButton
            profileButton
        }
        .overlay(playerPopupOverlay)
        .overlay(challengeDialogOverlay)
        .overlay(incomingChallengeOverlay)
        .overlay(resultPendingOverlay)
        .sheet(isPresented: $showChallengeView) {
            challengeSheet
        }
        .sheet(isPresented: $showProfile) {
            UserProfileView(
                data: UserProfileData(
                    name: ownPlayerName,
                    avatarImageName: "playerBoy",
                    rankName: ownRankName,
                    dailyStreak: ownDailyStreak,
                    totalChallenges: ownTotalChallenges,
                    wonChallenges: ownWonChallenges,
                    points: ownPoints
                ),
                pointsHistory: pointsHistory,
                battleHistory: battleHistory,
                profileStatusText: profileStatusText,
                profileBadges: profileBadges
            )
        }
        .onChange(of: showProfile) { isShown in
            if isShown {
                reloadOwnPlayerData()
            }
        }




        
        .fullScreenCover(isPresented: .constant(activeFullScreen != .none)) {
            switch activeFullScreen {
            case .battle:
                if let info = activeBattleInfo,
                   let battleId = currentBattleId {

                    if info.category == "Wissen" {
                        KnowledgeBattleView(
                            battleId: battleId,
                            socket: socket,
                            initialQuestion: lastKnowledgeQuestion,
                            onClose: { activeFullScreen = .none }
                        )

                    } else if info.category == "iPhone",
                              info.challengeName.contains("Check-In-Spot"),
                              let target = currentTargetCoordinate {

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

                    } else if info.category == "iPhone",
                              info.challengeName.contains("Sprint-Challenge") {
                        SprintChallengeView(
                            battleId: battleId,
                            playerId: ownPlayerId,
                            playerName: ownPlayerName,
                            socket: socket,
                            onClose: { activeFullScreen = .none }
                        )

                    } else if info.category == "iPhone",
                              info.challengeName.contains("Schrei-Challenge") {
                        LoudnessChallengeView(
                            battleId: battleId,
                            playerId: ownPlayerId,
                            socket: socket,
                            onClose: { activeFullScreen = .none }
                        )

                    } else if info.category == "iPhone",
                              info.challengeName.lowercased().contains("shake")
                              || info.challengeName.lowercased().contains("schüttel") {
                        ShakeChallengeView(
                            battleId: battleId,
                            socket: socket,
                            onClose: { activeFullScreen = .none }
                        )

                    } else {
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

                } else {
                    EmptyView()
                }





            case .win:
                if let data = resultData {
                    BattleWinView(data: data) {
                        activeFullScreen = .none   // zurück zur Map
                    }
                } else {
                    EmptyView()
                }


            case .lose:
                if let data = resultData {
                    BattleLoseView(data: data) {
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
                    ) { chosen in
                        myVote = chosen
                        socket.sendVote(
                            battleId: battleId,
                            winnerName: chosen
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
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.chalengrRed)
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
        .onAppear(perform: setupSocket)
        /// React to location updates
        .onReceive(locationHelper.$userLocation, perform: handleLocation)
        .onMapCameraChange { ctx in
                let heading = ctx.camera.heading    // 0 = Norden
                compassAngle = .degrees(heading)
            }
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
                    Image("playerBoy")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
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

                    Text(player.title.uppercased())
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.challengrBlack)

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
                        otherPlayerName: player.title,
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

    /// Overlay that appears when another player challenges the local player.
    private var incomingChallengeOverlay: some View {
        Group {
            if let challenge = incomingChallenge,
               let battleId = currentBattleId {

                let opponentName =
                    annotations.first(where: { $0.playerId == challenge.fromId })?.title
                    ?? "Gegner \(challenge.fromId)"

                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()

                    GameCard {
                        Text("CHALLENGE!")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(1.4)
                            .foregroundColor(.challengrYellow)

                        Text(opponentName.uppercased())
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.challengrDark)

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
                                    playerB: opponentName
                                )

                                incomingChallenge = nil
                                activeFullScreen = .battle
                            }

                            GamePrimaryButton(title: "Ablehnen", color: .challengrSurface) {
                                socket.sendUpdateBattleStatus(
                                    battleId: battleId,
                                    status: "DECLINED"
                                )

                                incomingChallenge = nil
                                currentBattleId = nil
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

    private var resultPendingOverlay: some View {
        Group {
            if activeOverlay == .resultPending {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        Text("ERGEBNIS WIRD BERECHNET")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
                    .shadow(radius: 10)
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
            do {
                let fitness  = try await challengesService.loadCategoryChallenges(category: "Fitness")
                let mutprobe = try await challengesService.loadCategoryChallenges(category: "Mutprobe")
                let wissen   = try await challengesService.loadCategoryChallenges(category: "Wissen")
                let iphone   = try await challengesService.loadCategoryChallenges(category: "iPhone")
                let customer = try await challengesService.loadCategoryChallenges(category: "Customer")

                allChallenges = fitness + mutprobe + wissen + iphone + customer
                print("AllChallenges geladen, Anzahl:", allChallenges.count)
            } catch {
                print("Fehler beim Vorladen der Challenges:", error)
            }
        }

        
        
        reloadOwnPlayerData()



        socket.onChallengeReceived = { battleId, fromId, toId, challengeId, targetLat, targetLon in
            let info = challengeInfo(for: challengeId)

            if toId == ownPlayerId {
                // Eingehende Challenge
                incomingChallenge = (
                    battleId: battleId,
                    fromId: fromId,
                    challengeId: challengeId,
                    name: info.name,
                    category: info.category
                )
                currentBattleId = battleId

            } else if fromId == ownPlayerId {
                // Wir sind der Angreifer
                outgoingBattleInfo = (
                    battleId: battleId,
                    opponentId: toId,
                    challengeName: info.name,
                    category: info.category
                )
                currentBattleId = battleId
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


        
        socket.onBattleAccepted = { battleId in
            
            print("🔥 onBattleAccepted: battleId:", battleId,
                      "currentBattleId:", currentBattleId as Any,
                      "incomingChallenge:", incomingChallenge as Any,
                      "outgoingBattleInfo:", outgoingBattleInfo as Any)
            // Muss unser Battle sein
            guard currentBattleId == battleId else { return }

            // Fall A: Wir wurden herausgefordert (incomingChallenge gesetzt)
            // Fall A: Wir wurden herausgefordert
            if let challenge = incomingChallenge {
                let opponentTitle =
                    annotations.first(where: { $0.playerId == challenge.fromId })?.title
                    ?? "Gegner \(challenge.fromId)"

                let opponentName = opponentTitle.components(separatedBy: " · ").first ?? opponentTitle

                activeBattleInfo = (
                    challengeName: challenge.name,
                    category: challenge.category,
                    playerA: ownPlayerName,   // schon ohne Rank
                    playerB: opponentName     // jetzt auch ohne Rank
                )

                incomingChallenge = nil
                activeFullScreen = .battle
                return
            }


            // Fall B: Wir sind der Angreifer (outgoingBattleInfo gesetzt)
            // Fall B: Wir sind der Angreifer
            if let outgoing = outgoingBattleInfo {
                let opponentTitle =
                    annotations.first(where: { $0.playerId == outgoing.opponentId })?.title
                    ?? "Gegner \(outgoing.opponentId)"

                let opponentName = opponentTitle.components(separatedBy: " · ").first ?? opponentTitle

                activeBattleInfo = (
                    challengeName: outgoing.challengeName,
                    category: outgoing.category,
                    playerA: ownPlayerName,
                    playerB: opponentName
                )

                activeFullScreen = .battle
                return
            }

        }


    
        
        socket.onBattleResult = { data in
            // NEU: Punkte/Streak nach Battle neu laden
            reloadOwnPlayerData()

            resultData = data
            activeFullScreen = .none

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                activeOverlay = .none
                if data.winnerName == ownPlayerName {
                    activeFullScreen = .win
                } else {
                    activeFullScreen = .lose
                }
            }
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

        
        socket.onBattleUpdatedStatus = { battleId, status in
            print("Battle \(battleId) status updated to \(status)")
        }
        
        socket.onKnowledgeQuestion = { battleId, challenge in
            print("📩 Knowledge question erhalten:", battleId, challenge.text)

            guard battleId == currentBattleId else { return }

            let payload = (
                battleId: battleId,
                text: challenge.text,
                choices: challenge.choices ?? []
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
                    "choices": payload.choices
                ]
            )
        }



    }

    /// Handles updates of the user location and refreshes nearby players.
    private func handleLocation(_ userLoc: CLLocationCoordinate2D?) {
        guard let userLoc = userLoc else { return }

        /// Make the camera follow the player.
        ownCoordinate = userLoc
        position = .camera(
            MapCamera(
                centerCoordinate: userLoc,
                distance: 1000,
                heading: 0,
                pitch: 0
            )
        )

        Task {
            do {
                let players = try await playerService.loadNearbyPlayers(
                    currentPlayerId: ownPlayerId,
                    latitude: userLoc.latitude,
                    longitude: userLoc.longitude,
                    radius: 200.0
                )

                annotations = players.map {
                    PlayerAnnotation(
                        playerId: $0.id,
                        coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                        title: "\($0.name) · \($0.rankName)"
                    )
                }

                if let me = players.first(where: { $0.id == ownPlayerId }) {
                    ownPlayerName = me.name
                }
            } catch {
                print("Fehler beim Laden der Nearby Players", error)
            }
        }
    }
}
