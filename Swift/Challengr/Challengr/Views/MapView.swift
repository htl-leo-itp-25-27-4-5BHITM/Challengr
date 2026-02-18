// MARK: - Imports

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

// MARK: - Models

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
    
    // MARK: - State & Services + Helpers
    
    /// Helper that provides the current user location
    @StateObject private var locationHelper = LocationHelper()
    
    /// Services to load from the backend
    private let playerService = PlayerLocationService()
    private let challengesService = ChallengesService()

    /// static player id
    let ownPlayerId: Int64 = 1

    /// WebSocket
    @StateObject private var socket = GameSocketService(playerId: 1)
    
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
    @State private var ownPlayerName: String = ""
    @State private var ownCoordinate: CLLocationCoordinate2D? = nil

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

    
    /// Cache of all challenges loaded from the backend (for all categories)
    @State private var allChallenges: [ChallengesService.Challenge] = []
    
    
    /// Resolves a challenge text and category name for a given challenge ID
    private func challengeInfo(for id: Int64) -> (name: String, category: String) {
        if let ch = allChallenges.first(where: { Int64($0.id) == id }) {
            return (ch.text, ch.challengeCategory.name)
        } else {
            return ("Challenge \(id)", "Unbekannt")
        }
    }

    /// Triggers a success haptic feedback.
    private func vibrate() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            mapLayer
            locationButton
            trophyRoadButton
        }
        .overlay(playerPopupOverlay)
        .overlay(challengeDialogOverlay)
        .overlay(incomingChallengeOverlay)
        .overlay(resultPendingOverlay)
        .sheet(isPresented: $showChallengeView) {
            challengeSheet
        }
        
        .fullScreenCover(isPresented: .constant(activeFullScreen != .none)) {
            switch activeFullScreen {
            case .battle:
                if let info = activeBattleInfo {
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
                                // optional, wenn du wie im Web auch noch einen Vote schicken willst:
                                // socket.sendVote(battleId: battleId, winnerName: info.playerB)
                            }
                            activeFullScreen = .none   // Battle schließen, Ergebnis kommt später über battle-result
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
    /// Trophy Road / Challenge Button
    private var trophyRoadButton: some View {
        VStack {
            Spacer()
            Button {
                showTrophyRoad = true // neues Binding für Trophy Road
            } label: {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .background(Color.challengrYellow)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .sheet(isPresented: $showTrophyRoad) {
                TrophyRoadView(playerId: ownPlayerId)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
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






    // MARK: - Logik

    /// Sets up the WebSocket connection and preloads all challenges.
    private func setupSocket() {
        socket.connect()

        // Preload challenges for all categories once at startup.
        Task {
            do {
                let fitness = try await challengesService.loadCategoryChallenges(category: "Fitness")
                let mutprobe = try await challengesService.loadCategoryChallenges(category: "Mutprobe")
                let wissen  = try await challengesService.loadCategoryChallenges(category: "Wissen")
                let suchen  = try await challengesService.loadCategoryChallenges(category: "Suchen")

                allChallenges = fitness + mutprobe + wissen + suchen
                print("AllChallenges geladen, Anzahl:", allChallenges.count)
            } catch {
                print("Fehler beim Vorladen der Challenges:", error)
            }
        }
        
        Task {
                do {
                    let me = try await playerService.loadPlayerById(id: ownPlayerId)
                    ownPlayerName = me.name
                    print("ownPlayerName aus DB:", ownPlayerName)
                } catch {
                    print("Konnte eigenen Spieler nicht laden:", error)
                }
            }

        socket.onChallengeReceived = { battleId, fromId, toId, challengeId in
            if toId == ownPlayerId {
                // wie bisher: eingehende Challenge
                let info = challengeInfo(for: challengeId)
                incomingChallenge = (
                    battleId: battleId,
                    fromId: fromId,
                    challengeId: challengeId,
                    name: info.name,
                    category: info.category
                )
                currentBattleId = battleId
            } else if fromId == ownPlayerId {
                // NEU: wir sind der Angreifer
                let info = challengeInfo(for: challengeId)
                outgoingBattleInfo = (
                    battleId: battleId,
                    opponentId: toId,
                    challengeName: info.name,
                    category: info.category
                )
                currentBattleId = battleId
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
            
            resultData = data
            activeFullScreen = .none

            // 5 Sekunden warten, danach Win/Lose anzeigen
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
