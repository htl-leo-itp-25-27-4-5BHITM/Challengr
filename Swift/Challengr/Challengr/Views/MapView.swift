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
    /// Stabil pro Spieler, damit Pins beim Aktualisieren nicht neu entstehen (Bewegung wird animiert).
    var id: String { playerId }
    let playerId: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let rankName: String
    /// Gewählte Figur des Spielers (nil = unbekannt, z.B. alte App-Version).
    var character: GameCharacter? = nil
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

    // Lebendige Karte: Emoji-Blasen über Spielern und "neu in der Nähe"-Hinweise
    /// Echte Emotes anderer Spieler auf der Karte (playerId → Emoji)
    @State private var pinBubbles: [String: String] = [:]
    /// Eigenes zuletzt gesendetes Emote (Karte)
    @State private var ownMapEmote: EmoteEvent? = nil
    /// Emotes im laufenden Battle
    @State private var ownBattleEmote: EmoteEvent? = nil
    @State private var opponentBattleEmote: EmoteEvent? = nil

    // Hotspots (z.B. die Schule): täglicher Check-in mit Bonus
    @State private var hotspots: [HotspotDTO] = []
    @State private var selectedHotspotId: String? = nil
    @State private var isCheckingIn = false
    @State private var announcedHotspotIds: Set<String> = []
    @State private var lastHotspotLoad: Date? = nil
    @State private var knownNearbyIds: [String]? = nil
    /// Figur des Gegners im laufenden Battle
    @State private var battleOpponentCharacter: GameCharacter? = nil
    /// Modus des laufenden Battles (Liga Wissen → Quiz-Show, Friendly → Geschafft ohne Voting)
    @State private var battleMode: BattleMode = .friendly
    /// Friendly: selbst "Geschafft" gemeldet bzw. der Gegner hat es geschafft
    @State private var friendlyWaiting = false
    @State private var opponentFinished = false
    /// Quiz-Show lebt hier, damit keine Frage verloren geht, bevor der Screen offen ist
    @StateObject private var quizModel: QuizShowModel

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
    /// Liga-Trophäen (Quiz-Show und Real-Life gemeinsam)
    @State private var ownTrophies: Int? = nil
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
        _quizModel = StateObject(wrappedValue: QuizShowModel(ownPlayerId: resolvedPlayerId))
    }

    init(ownPlayerId: String, ownPlayerName: String, auth: KeycloakAuthService) {
        let resolvedPlayerName = ownPlayerName.isEmpty ? "Player" : ownPlayerName

        self.ownPlayerId = ownPlayerId
        self.auth = auth
        _ownPlayerName = State(initialValue: resolvedPlayerName)
        _locationHelper = StateObject(wrappedValue: LocationHelper(playerId: ownPlayerId, playerName: resolvedPlayerName))
        _socket = StateObject(wrappedValue: GameSocketService(playerId: ownPlayerId))
        _quizModel = StateObject(wrappedValue: QuizShowModel(ownPlayerId: ownPlayerId))
    }

    
    /// Current map camera position and Zoom
    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
            distance: 1000,
            heading: 0,
            pitch: MapView.mapPitch
        )
    )

    /// Karte schräg von der Seite (isometrisch wirkend) statt direkt von oben.
    static let mapPitch: Double = 55
    
    @State private var myVote: String? = nil
    @State private var opponentVote: String? = nil

    @State private var activeOverlay: ActiveOverlay = .none
    @State private var hasCenteredOnUser = false
    @State private var currentZoomDistance: CLLocationDistance = 1000
    @State private var isProgrammaticCameraUpdate = false
    @State private var isFollowingUser = true
    @State private var hasCapturedInitialZoom = false

    let minDistance: CLLocationDistance = 200
    let maxDistance: CLLocationDistance = 2500

    /// Wo zuletzt auf die Karte getippt wurde – kurze Welle als Rückmeldung.
    @State private var mapTaps: [MapTapMark] = []

    
    /// All players that should be displayed
    @State private var annotations: [PlayerAnnotation] = []
    /// Alle Spieler in der Nähe laut Server (auf der Karte stehen höchstens die 30 nächsten)
    @State private var nearbyTotal = 0

    /// Rank name -> rank color, used to tint player pins on the map.
    @State private var rankColorsByName: [String: Color] = [:]
    private let rankService = RankService()
    
    /// Challenge Infos Window
    @State private var showChallengeView = false
    @State private var showTrophyRoad = false
    @State private var showMainMenu = false
    @State private var showCharacterEditor = false
    @State private var profileStartTab = 0
    @StateObject private var menuAvatarStore = AvatarCustomizationStore()

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
    @State private var lastMapCamera: MapCamera? = nil
    
    var body: some View {
        
        ZStack {
            // Map-Ebene
            mapLayer
                // Voller Schulhof: Figuren-Animationen sparsamer, damit die Karte flüssig bleibt
                .environment(\.mapCrowded, annotations.count > MapCrowd.threshold)

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
                                        pitch: MapView.mapPitch
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
                            let count = max(nearbyTotal, annotations.count)
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

                    // RECHTS: nur der Kompass – Einstellungen und Shop sind im Haupt-Menü
                    VStack(spacing: 8) {
                        CompassView(angle: compassAngle) {
                            // position.camera ist leer, solange die Karte dem Standort folgt –
                            // deshalb die zuletzt gemeldete Kamera nehmen.
                            guard let cam = lastMapCamera ?? position.camera else { return }
                            SoundManager.shared.play(.tap)
                            withAnimation(.easeOut(duration: 0.35)) {
                                position = .camera(MapCamera(
                                    centerCoordinate: cam.centerCoordinate,
                                    distance: cam.distance,
                                    heading: 0,
                                    pitch: cam.pitch
                                ))
                            }
                        }
                    }
                }
                .padding(.top, 28)
                .padding(.horizontal, 18)

                HStack {
                    trophiesChip
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.horizontal, 18)

                Spacer()
            }


                    // 3) UNTERER BEREICH: Menü-Münze mittig, Profil rechts
                    profileButton
                    hotspotCheckinChip
                    mainMenu
                }
        .overlay(playerPopupOverlay)
        .overlay(hotspotPopupOverlay)
        .overlay(challengeDialogOverlay)
        .overlay(incomingChallengeOverlay)
        .overlay(outgoingChallengeOverlay)
        .overlay(resultPendingOverlay)
        .overlay(alignment: .top) { mapBannerOverlay }
        .sheet(isPresented: $showChallengeView) {
            challengeSheet
        }
        .onChange(of: showSettings) { _, shown in
            // z.B. neuer Name aus den Einstellungen
            if !shown { reloadOwnPlayerData() }
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
                initialTab: profileStartTab,
                data: UserProfileData(
                    name: ownPlayerName,
                    avatarImageName: AvatarPresets.persistedAvatarImageName(),
                    rankName: ownRankName,
                    dailyStreak: ownDailyStreak,
                    totalChallenges: ownTotalChallenges,
                    wonChallenges: ownWonChallenges,
                    points: ownPoints,
                    trophies: ownTrophies
                ),
                battleHistory: battleHistory,
                profileStatusText: profileStatusText,
                profileBadges: profileBadges,
                rankColor: rankColor(for: ownRankName),
                allChallenges: allChallenges,
                socket: socket,
                currentCoordinate: ownCoordinate
            )
        }
        .onChange(of: currentBattleId) { _, battleId in
            guard let battleId else { return }
            battleMode = socket.modeByBattle[battleId] ?? .friendly
            friendlyWaiting = false
            opponentFinished = false
            if battleMode == .rankedKnowledge { quizModel.start(battleId: battleId) }
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

                    if battleMode == .rankedKnowledge {
                        QuizShowView(
                            model: quizModel,
                            battleId: battleId,
                            ownName: ownPlayerName,
                            opponentName: info.playerB,
                            ownCharacter: GameCharacter.current,
                            opponentCharacter: battleOpponentCharacter ?? .opponent,
                            socket: socket,
                            onSurrendered: { activeFullScreen = .none; activeOverlay = .resultPending }
                        )
                    } else {
                    switch BattleScreen.forChallenge(category: info.category, name: info.challengeName) {
                    case .knowledge:
                        KnowledgeBattleView(
                            battleId: battleId,
                            socket: socket,
                            initialQuestion: lastKnowledgeQuestion,
                            // Schließen = Aufgeben → Ergebnis kommt vom Server
                            onClose: { activeFullScreen = .none; activeOverlay = .resultPending }
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
                                // Schließen = Aufgeben → Ergebnis kommt vom Server
                                onClose: {
                                    activeFullScreen = .none
                                    activeOverlay = .resultPending
                                }
                            )
                        } else {
                            // Ohne Zielpunkt kein Check-In – aber auch kein "Geschafft"-Voting wie im
                            // normalen Battle: nur Aufgeben ist möglich.
                            ZStack {
                                Color.challengrDark.ignoresSafeArea()
                                VStack(spacing: 18) {
                                    Text("CHECK-IN-SPOT")
                                        .font(.system(size: 22, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("Der Zielpunkt konnte nicht geladen werden.")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                    ChallengeSurrenderButton(battleId: battleId, socket: socket) {
                                        activeFullScreen = .none
                                        activeOverlay = .resultPending
                                    }
                                }
                                .padding(24)
                            }
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
                    }

                } else {
                    EmptyView()
                }





            case .win:
                if let data = resultData {
                    BattleWinView(data: data, ownPlayerName: ownPlayerName) {
                        activeFullScreen = .none   // zurück zur Map
                        Task { await syncCharacterAndUnlocks() }
                    }
                } else {
                    EmptyView()
                }


            case .lose:
                if let data = resultData {
                    BattleLoseView(data: data, ownPlayerName: ownPlayerName) {
                        activeFullScreen = .none   // schließt das Fullscreen-Cover
                        Task { await syncCharacterAndUnlocks() }
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
            ),
            // Drehen und Zoomen, aber kein Verschieben oder Kippen (bleibt immer 3D, nie Draufsicht)
            interactionModes: [.rotate, .zoom]
        ) {
            /// 200m radius around ownplayer
            if let ownCoordinate {
                MapCircle(center: ownCoordinate, radius: 200)
                    .foregroundStyle(Color.blue.opacity(0.2))
                    .stroke(Color.blue.opacity(0.6), lineWidth: 2)

                Annotation("Du", coordinate: ownCoordinate, anchor: .bottom) {
                    MapCharacterPin(
                        character: AvatarPresets.persistedPreset().character ?? .own,
                        ringColor: .challengrYellow,
                        sonar: true,
                        seed: ownPlayerId
                    )
                    .overlay(alignment: .top) { EmoteBubble(event: ownMapEmote).scaleEffect(0.7).offset(y: -30) }
                }
            }

            // Hotspots (Check-in-Punkte)
            ForEach(hotspots) { hotspot in
                MapCircle(center: hotspot.coordinate, radius: hotspot.radiusMeters)
                    .foregroundStyle(Color.challengrYellow.opacity(0.18))
                    .stroke(Color.challengrYellow.opacity(0.8), lineWidth: 2)
                Annotation(hotspot.name, coordinate: hotspot.coordinate, anchor: .bottom) {
                    Button {
                        closePlayerPopup()
                        withAnimation { selectedHotspotId = hotspot.id }
                    } label: {
                        HotspotMarker(name: hotspot.name, checkedIn: hotspot.checkedInToday)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Annotations for all nearby players.
            ForEach(annotations) { annotation in
                Annotation(annotation.title, coordinate: annotation.coordinate, anchor: .bottom) {
                    LivelyPin(seed: annotation.playerId, bubble: pinBubbles[annotation.playerId], bobs: false) {
                        Button {
                            if selectedPlayer?.id == annotation.id {
                                showPlayerPopup.toggle()
                            } else {
                                selectedPlayer = annotation
                                showPlayerPopup = true
                            }
                        } label: {
                            MapCharacterPin(
                                character: annotation.character ?? .opponent,
                                ringColor: rankColor(for: annotation.rankName),
                                seed: annotation.playerId
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(annotation.title)
                    }
                }
            }
        }
        // Kein eingebauter MapKit-Kompass – wir haben einen eigenen
        .mapControls { }
        .mapStyle(
            .standard(
                elevation: .realistic,
                pointsOfInterest: .excludingAll,
                showsTraffic: false
            )
        )
        .simultaneousGesture(SpatialTapGesture().onEnded { showTapMark(at: $0.location) })
        .overlay {
            ForEach(mapTaps) { MapTapRipple().position($0.location) }
                .allowsHitTesting(false)
        }
        .sensoryFeedback(.selection, trigger: mapTaps.count) { old, new in new > old }
        .tint(.challengrGreen)
        .accentColor(.challengrYellow)
        .ignoresSafeArea()
        .onAppear {
            setupSocket()
            Task { await syncCharacterAndUnlocks() }
            Task { await loadHotspots() }
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
        // Kompass während des Drehens laufend nachführen (nicht erst am Ende der Geste)
        .onMapCameraChange(frequency: .continuous) { ctx in
            compassAngle = .degrees(ctx.camera.heading)    // 0 = Norden
            lastMapCamera = ctx.camera
        }
        .onMapCameraChange { ctx in
                if !isProgrammaticCameraUpdate {
                    currentZoomDistance = ctx.camera.distance
                    if !hasCapturedInitialZoom {
                        hasCapturedInitialZoom = true
                    }
                    if let ownCoordinate {
                        let center = ctx.camera.centerCoordinate
                        let deltaLat = abs(center.latitude - ownCoordinate.latitude)
                        let deltaLon = abs(center.longitude - ownCoordinate.longitude)
                        // Zoomen verschiebt die Mitte (zum Finger hin) – zurück zum Spieler
                        if deltaLat > 0.00025 || deltaLon > 0.00025 {
                            recenter(on: ownCoordinate, keeping: ctx.camera)
                        }
                    }
                }
            }
    }

    /// Immer sichtbarer Trophäen-Stand, öffnet die Trophy Road.
    private var trophiesChip: some View {
        Button {
            showTrophyRoad = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.challengrYellow)
                Text("\(ownTrophies ?? 0)")
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
                        pitch: MapView.mapPitch
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

    /// Haupt-Menü: 3D-Münze unten in der Mitte, öffnet Trophy Road, Shop, Figur, Freunde, Einstellungen.
    private var mainMenu: some View {
        MapMainMenu(isOpen: $showMainMenu, items: [
            MapMenuItem(id: "trophy", title: "Trophy Road", systemImage: "trophy.fill", color: .challengrYellow) {
                showTrophyRoad = true
            },
            MapMenuItem(id: "shop", title: "Shop", systemImage: "bag.fill", color: .challengrGreen) {
                showShop = true
            },
            MapMenuItem(id: "character", title: "Figur", systemImage: "figure.fencing", color: .challengrRed) {
                menuAvatarStore.load()
                showCharacterEditor = true
            },
            MapMenuItem(id: "friends", title: "Freunde", systemImage: "person.2.fill", color: .blue,
                        badge: friendsInbox.pendingIncomingCount) {
                reloadOwnPlayerData()
                profileStartTab = 1
                showProfile = true
            },
            MapMenuItem(id: "settings", title: "Einstellungen", systemImage: "gearshape.fill", color: .gray) {
                showSettings = true
            }
        ])
        .sheet(isPresented: $showTrophyRoad) {
            TrophyRoadView(playerId: ownPlayerId)
        }
        .sheet(isPresented: $showCharacterEditor) {
            CharacterEditorSheet(store: menuAvatarStore, playerId: ownPlayerId)
        }
    }

    // Profil
    private var profileButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    reloadOwnPlayerData()
                    profileStartTab = 0
                    showProfile = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(AvatarPresets.persistedAvatarImageName())
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
              ZStack {
                // Tipp irgendwo auf die Karte schließt das Popup
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { closePlayerPopup() }

                VStack(spacing: 10) {

                    MapAvatarPin(
                        imageName: (player.character ?? .opponent).avatarImageName,
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

                    // Emote schicken statt gleich herausfordern
                    HStack(spacing: 6) {
                        ForEach(Emotes.map, id: \.self) { emoji in
                            Button { sendMapEmote(emoji, to: player) } label: {
                                Text(emoji)
                                    .font(.system(size: 22))
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color.white.opacity(0.85)))
                            }
                            .accessibilityLabel("Emote \(emoji) an \(cleanPlayerName(player.title)) senden")
                        }
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
                // Melden / Blockieren (Apple-Regel 1.2)
                .overlay(alignment: .topTrailing) {
                    PlayerSafetyMenu(playerId: player.playerId, playerName: cleanPlayerName(player.title)) {
                        let blockedId = player.playerId
                        closePlayerPopup()
                        withAnimation { annotations.removeAll { $0.playerId == blockedId } }
                        showMapBanner(icon: "hand.raised.fill", text: "Blockiert – ihr seht euch nicht mehr")
                    }
                    .padding(4)
                }
                .shadow(radius: 15)
                .padding(.top, 80)
                .transition(.scale)
              }
            }
        }
    }

    /// Name eines Gegners: Karte → Battle-Nachricht vom Server → neutral. Nie die rohe Id (BUG-15).
    private func opponentDisplayName(_ playerId: String, battleId: Int64?) -> String {
        if let annotation = annotations.first(where: { $0.playerId == playerId }) {
            return cleanPlayerName(annotation.title)
        }
        if let battleId, let p = socket.participantsByBattle[battleId],
           let name = p.fromId == playerId ? p.fromName : p.toName {
            return name
        }
        return "Gegner"
    }

    /// Figur eines Gegners: Battle-Nachricht → Karte → Ersatz-Figur.
    private func opponentCharacter(_ playerId: String, battleId: Int64?) -> GameCharacter {
        if let battleId, let p = socket.participantsByBattle[battleId],
           let character = p.fromId == playerId ? p.fromCharacter : p.toCharacter {
            return character
        }
        return annotations.first(where: { $0.playerId == playerId })?.character ?? .opponent
    }

    /// Gewählte Figur am Server spiegeln und neu freigeschaltete Figuren ankündigen.
    @MainActor
    private func syncCharacterAndUnlocks() async {
        guard !ownPlayerId.isEmpty else { return }
        let service = CharacterService()
        do {
            try await service.selectCharacter(playerId: ownPlayerId, character: GameCharacter.current)
        } catch let error as CharacterServiceError where error.isLocked {
            // Lokal gespeicherte Figur ist am Server (noch) gesperrt → zurück zur Start-Figur
            UserDefaults.standard.set(GameCharacter.own.rawValue, forKey: AvatarCustomizationStore.presetKey)
            try? await service.selectCharacter(playerId: ownPlayerId, character: .own)
        } catch {
            print("Figur konnte nicht synchronisiert werden:", error)
        }

        guard let unlocks = try? await service.loadCharacters(playerId: ownPlayerId),
              let first = CharacterUnlockTracker.newlyUnlocked(unlocks).first else { return }
        SoundManager.shared.play(.win)
        showMapBanner(icon: "lock.open.fill", text: "\(first.displayName) freigeschaltet! Im Profil auswählen")
    }

    private func closePlayerPopup() {
        withAnimation {
            showPlayerPopup = false
            selectedPlayer = nil
        }
    }

    // MARK: - Lebendige Karte

    // MARK: - Hotspots

    private var selectedHotspot: HotspotDTO? {
        hotspots.first { $0.id == selectedHotspotId }
    }

    @MainActor
    private func loadHotspots() async {
        guard !ownPlayerId.isEmpty else { return }
        lastHotspotLoad = Date()
        guard let list = try? await HotspotService().load(playerId: ownPlayerId) else { return }
        hotspots = list
        announceHotspotIfNear()
    }

    /// Beim ersten Erscheinen der Karte ist die Spieler-Id evtl. noch leer → beim Standort-Update nachladen.
    private func loadHotspotsIfNeeded() {
        guard !ownPlayerId.isEmpty else { return }
        let firstLoadMissing = hotspots.isEmpty && (lastHotspotLoad.map { Date().timeIntervalSince($0) > 20 } ?? true)
        // Nach Mitternacht kann man wieder einchecken → Stand neu holen
        let newDay = lastHotspotLoad.map { HotspotSchedule.isStale(loadedAt: $0) } ?? false
        guard firstLoadMissing || newDay else { return }
        if newDay { announcedHotspotIds.removeAll() }
        Task { await loadHotspots() }
    }

    /// Kommt man in den Radius eines Hotspots, einmal kurz darauf hinweisen.
    private func announceHotspotIfNear() {
        for hotspot in hotspots where !announcedHotspotIds.contains(hotspot.id) {
            if HotspotState.of(hotspot, playerAt: ownCoordinate) == .inRange {
                announcedHotspotIds.insert(hotspot.id)
                showMapBanner(icon: "bolt.circle.fill", text: "Du bist bei \(hotspot.name) – jetzt einchecken!",
                              seconds: 6)
            }
        }
    }

    @MainActor
    private func checkIn(_ hotspot: HotspotDTO) async {
        guard let coordinate = ownCoordinate, !isCheckingIn else { return }
        isCheckingIn = true
        defer { isCheckingIn = false }
        do {
            let result = try await HotspotService().checkin(hotspotId: hotspot.id, playerId: ownPlayerId, coordinate: coordinate)
            SoundManager.shared.play(.purchase)
            withAnimation { selectedHotspotId = nil }
            ownPoints = result.totalPoints
            showMapBanner(icon: result.firstOfDay ? "crown.fill" : "checkmark.seal.fill",
                          text: result.firstOfDay
                            ? "Eingecheckt – du bist heute der Erste bei \(hotspot.name)!"
                            : "Eingecheckt bei \(hotspot.name)!")
            reloadOwnPlayerData()
        } catch {
            SoundManager.shared.play(.purchaseFailed)
            showMapBanner(icon: "exclamationmark.triangle.fill", text: error.localizedDescription)
        }
        await loadHotspots()
    }

    /// Hotspot, an dem man gerade steht und heute noch einchecken kann.
    private var hotspotInRange: HotspotDTO? {
        hotspots.first { HotspotState.of($0, playerAt: ownCoordinate) == .inRange }
    }

    /// Großer Einchecken-Button über der Menü-Münze, solange man an einem Hotspot steht.
    /// Der Marker selbst liegt oft unter dem eigenen Pin – so muss man ihn nicht treffen.
    private var hotspotCheckinChip: some View {
        VStack {
            Spacer()
            if let hotspot = hotspotInRange, !showMainMenu, selectedHotspotId == nil, !showPlayerPopup,
               incomingChallenge == nil, outgoingBattleInfo == nil {
                Button {
                    Task { await checkIn(hotspot) }
                } label: {
                    HStack(spacing: 10) {
                        Image("MenuCoin").resizable().scaledToFit().frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isCheckingIn ? "…" : "EINCHECKEN")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .tracking(1)
                            Text(hotspot.checkinsToday == 0 ? "\(hotspot.name) · sei heute der Erste!" : hotspot.name)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(.challengrDark)
                    .padding(.vertical, 8)
                    .padding(.leading, 10)
                    .padding(.trailing, 18)
                    .background(Capsule().fill(Color.challengrYellow))
                    .overlay(Capsule().stroke(Color.challengrDark, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(isCheckingIn)
                .accessibilityLabel("Einchecken bei \(hotspot.name)")
                .transition(.scale.combined(with: .opacity))
                .padding(.bottom, 140)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hotspotInRange?.id)
    }

    private var hotspotPopupOverlay: some View {
        Group {
            if let hotspot = selectedHotspot {
                let state = HotspotState.of(hotspot, playerAt: ownCoordinate)
                ZStack {
                    // Tipp auf die Karte schließt das Popup
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { selectedHotspotId = nil } }

                    VStack(spacing: 10) {
                        Image("MenuCoin")
                            .resizable().scaledToFit()
                            .frame(width: 56, height: 56)
                            .saturation(hotspot.checkedInToday ? 0 : 1)

                        Text(hotspot.name.uppercased())
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.challengrBlack)

                        Text("HOTSPOT · 1 CHECK-IN PRO TAG")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(Color.challengrRed)

                        Text(hotspot.checkinsToday == 0
                             ? "Noch niemand heute – der Erste bekommt +\(hotspot.firstOfDayBonus) extra!"
                             : "Heute schon \(hotspot.checkinsToday)× eingecheckt.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.challengrBlack.opacity(0.75))

                        switch state {
                        case .checkedIn:
                            VStack(spacing: 4) {
                                Label("Heute erledigt", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.challengrGreen)
                                TimelineView(.periodic(from: .now, by: 30)) { context in
                                    Text("Wieder einchecken in \(HotspotSchedule.remainingText(until: HotspotSchedule.nextCheckin(after: context.date), now: context.date))")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.challengrBlack.opacity(0.7))
                                }
                            }
                        case .inRange:
                            Button {
                                Task { await checkIn(hotspot) }
                            } label: {
                                Text(isCheckingIn ? "…" : "EINCHECKEN")
                                    .font(.system(size: 14, weight: .black))
                                    .tracking(1)
                                    .foregroundStyle(.challengrBlack)
                                    .padding(.vertical, 11)
                                    .padding(.horizontal, 22)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.challengrYellow))
                            }
                            .disabled(isCheckingIn)
                        case .tooFar(let meters):
                            Text("Noch \(meters) m – geh näher hin")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.challengrBlack.opacity(0.7))
                        case .noLocation:
                            Text("Standort wird gesucht …")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.challengrBlack.opacity(0.7))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: 280)
                    .background(RoundedRectangle(cornerRadius: 18).fill(.regularMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.15), lineWidth: 1))
                    .shadow(radius: 15)
                    .environment(\.colorScheme, .light)
                    .transition(.scale)
                }
            }
        }
    }

    /// Emote an einen Spieler auf der Karte schicken (aus dem Spieler-Popup).
    private func sendMapEmote(_ emoji: String, to player: PlayerAnnotation) {
        socket.sendEmote(toId: player.playerId, emoji: emoji)
        SoundManager.shared.play(.tap)
        let event = EmoteEvent(emoji: emoji)
        ownMapEmote = event
        closePlayerPopup()
        DispatchQueue.main.asyncAfter(deadline: .now() + Emotes.visibleSeconds) {
            if ownMapEmote == event { ownMapEmote = nil }
        }
    }

    /// Emote im Battle an den Gegner.
    private func sendBattleEmote(_ emoji: String, opponentId: String) {
        guard let battleId = currentBattleId else { return }
        socket.sendEmote(toId: opponentId, emoji: emoji, battleId: battleId)
        let event = EmoteEvent(emoji: emoji)
        ownBattleEmote = event
        DispatchQueue.main.asyncAfter(deadline: .now() + Emotes.visibleSeconds) {
            if ownBattleEmote == event { ownBattleEmote = nil }
        }
    }

    /// Emote von einem anderen Spieler: im Battle über der Gegner-Figur, sonst über seinem Pin.
    private func receiveEmote(from playerId: String, emoji: String, battleId: Int64?) {
        if let battleId {
            guard battleId == currentBattleId else { return }
            let event = EmoteEvent(emoji: emoji)
            opponentBattleEmote = event
            DispatchQueue.main.asyncAfter(deadline: .now() + Emotes.visibleSeconds) {
                if opponentBattleEmote == event { opponentBattleEmote = nil }
            }
            return
        }
        guard activeFullScreen == .none else { return }
        if annotations.contains(where: { $0.playerId == playerId }) {
            pinBubbles[playerId] = emoji
            DispatchQueue.main.asyncAfter(deadline: .now() + Emotes.visibleSeconds + 0.5) {
                if pinBubbles[playerId] == emoji { pinBubbles[playerId] = nil }
            }
        } else {
            showMapBanner(icon: "face.smiling", text: "\(opponentDisplayName(playerId, battleId: nil)) schickt dir \(emoji)")
        }
    }

    /// Neue Spieler im Radius kurz ankündigen.
    private func announceArrivals(_ players: [PlayerAnnotation]) {
        let ids = players.map(\.playerId)
        let arrivals = MapVibe.newArrivals(previous: knownNearbyIds, current: ids)
        knownNearbyIds = ids
        guard let first = arrivals.first,
              let player = players.first(where: { $0.playerId == first }),
              activeFullScreen == .none, !showPlayerPopup else { return }
        let name = cleanPlayerName(player.title)
        let text = arrivals.count == 1
            ? "\(name) ist in deiner Nähe – fordere ihn heraus!"
            : "\(name) und \(arrivals.count - 1) weitere sind in deiner Nähe!"
        showMapBanner(icon: "bolt.fill", text: text)
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
                        otherPlayerCharacter: opponentCharacter(player.playerId, battleId: nil),
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

    /// Modus einer Anfrage: Liga Wissen / Liga Real-Life / Friendly.
    private func modeBadge(_ mode: BattleMode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: mode.icon)
            Text(mode.title.uppercased()).tracking(0.8)
            if mode.isRanked { Image(systemName: "trophy.fill").foregroundColor(.challengrYellow) }
        }
        .font(.system(size: 12, weight: .black, design: .rounded))
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(mode.color))
        .accessibilityLabel("Modus: \(mode.title)")
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
                let opponentName = opponentDisplayName(challenge.fromId, battleId: battleId)
                let opponentRingColor = opponentAnnotation.map { rankColor(for: $0.rankName) } ?? .gray

                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()

                    GameCard {
                        Text("CHALLENGE!")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(1.4)
                            .foregroundColor(.challengrYellow)

                        MapAvatarPin(imageName: opponentCharacter(challenge.fromId, battleId: battleId).avatarImageName,
                                     ringColor: opponentRingColor, isOwnPlayer: false)

                        Text(opponentName.uppercased())
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.challengrDark)

                        HStack(spacing: 8) {
                            let mode = socket.modeByBattle[battleId] ?? .friendly
                            modeBadge(mode)
                            if mode == .friendly { categoryBadge(for: challenge.category) }
                        }

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
                                battleOpponentCharacter = opponentCharacter(challenge.fromId, battleId: battleId)

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
                let opponentName = opponentDisplayName(outgoing.opponentId, battleId: outgoing.battleId)
                let outgoingRingColor = outgoingAnnotation.map { rankColor(for: $0.rankName) } ?? .gray

                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    GameCard {
                        Text("ANFRAGE GESENDET")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(.challengrYellow)

                        MapAvatarPin(imageName: opponentCharacter(outgoing.opponentId, battleId: outgoing.battleId).avatarImageName,
                                     ringColor: outgoingRingColor, isOwnPlayer: false)

                        Text(opponentName.uppercased())
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.challengrDark)

                        modeBadge(socket.modeByBattle[outgoing.battleId] ?? .friendly)

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
            opponentCharacter: battleOpponentCharacter ?? .opponent,
            ownEmote: ownBattleEmote,
            opponentEmote: opponentBattleEmote,
            onSendEmote: { emoji in sendBattleEmote(emoji, opponentId: info.opponentId) },
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
                // Kein Voting mehr: "Geschafft" melden; haben es beide geschafft → Unentschieden
                guard let battleId = currentBattleId, !friendlyWaiting else { return }
                socket.sendFriendlyFinished(battleId: battleId)
                friendlyWaiting = true
            },
            waitingForOpponent: friendlyWaiting,
            opponentFinished: opponentFinished
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

    private func showMapBanner(icon: String, text: String, seconds: Double = 3) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            mapBanner = (icon: icon, text: text)
        }
        mapBannerHideTask?.cancel()
        mapBannerHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
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
                async let battlesAsync = playerService.loadPlayerBattles(id: ownPlayerId)
                async let profileAsync = playerService.loadPlayerProfile(id: ownPlayerId)

                let points = try await pointsAsync
                let streak = try await streakAsync
                let stats  = try await statsAsync
                let battles = (try? await battlesAsync) ?? []
                let profile = (try? await profileAsync) ?? PlayerProfileDTO(status: nil, badges: [])

                await MainActor.run {
                    ownPlayerName      = name
                    ownRankName        = rank
                    ownTrophies        = me.trophies
                    ownPoints          = points
                    ownDailyStreak     = streak
                    ownTotalChallenges = stats.totalChallenges
                    ownWonChallenges   = stats.wonChallenges
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
                print("Anfrage \(battleId) automatisch abgelehnt – isInBattle: fullScreen=\(activeFullScreen), overlay=\(activeOverlay), battle=\(currentBattleId.map(String.init) ?? "nil")")
                socket.sendUpdateBattleStatus(battleId: battleId, status: "DECLINED")
                // Auch auf dem eigenen Handy anzeigen, damit man sieht, warum nichts kam
                let fromName = cleanPlayerName(annotations.first(where: { $0.playerId == fromId })?.title ?? "Spieler")
                showMapBanner(icon: "hand.raised.fill", text: "Anfrage von \(fromName) abgelehnt – du bist noch in einem Battle")
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
                let extras = socket.runningExtras[battleId] ?? RunningBattleExtras()
                incomingChallenge = nil
                outgoingBattleInfo = nil
                activeBattleInfo = (
                    challengeName: info.name,
                    category: info.category,
                    playerA: ownPlayerName,
                    playerB: opponentDisplayName(opponentId, battleId: battleId),
                    opponentId: opponentId
                )
                battleOpponentCharacter = opponentCharacter(opponentId, battleId: battleId)
                // Check-In-Spot braucht den Zielpunkt, sonst landet man im normalen Battle-Screen
                if let lat = extras.targetLatitude, let lon = extras.targetLongitude {
                    currentTargetCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                switch BattleRestore.screen(status: status, submitted: extras.submitted) {
                case .waitForResult: activeOverlay = .resultPending
                case .voting:        activeFullScreen = .voting
                case .battle:        activeFullScreen = .battle
                }
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
                let opponentName = opponentDisplayName(challenge.fromId, battleId: battleId)
                battleOpponentCharacter = opponentCharacter(challenge.fromId, battleId: battleId)

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
                let opponentName = opponentDisplayName(outgoing.opponentId, battleId: battleId)
                battleOpponentCharacter = opponentCharacter(outgoing.opponentId, battleId: battleId)

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

        socket.onEmote = { fromId, emoji, battleId in
            receiveEmote(from: fromId, emoji: emoji, battleId: battleId)
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

        socket.onQuizQuestion = { question in
            guard question.battleId == currentBattleId else { return }
            quizModel.receive(question)
        }

        socket.onQuizRoundResult = { result in
            guard result.battleId == currentBattleId else { return }
            quizModel.receive(result)
        }

        socket.onQuizOpponentAnswered = { battleId, round in
            quizModel.opponentDidAnswer(battleId: battleId, round: round)
        }

        socket.onOpponentFinished = { battleId in
            guard battleId == currentBattleId else { return }
            opponentFinished = true
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
        loadHotspotsIfNeeded()
        announceHotspotIfNear()
        if !hasCenteredOnUser {
            hasCenteredOnUser = true
            isFollowingUser = true
        }

        guard isFollowingUser else { return }
        guard hasCapturedInitialZoom else { return }

        let currentCamera = position.camera
        let heading = currentCamera?.heading ?? 0
        let pitch = currentCamera?.pitch ?? MapView.mapPitch
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
            let (players, total) = try await playerService.loadNearbyWithTotal(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radius: 200.0
            )
            nearbyTotal = total

            // Der eigene Spieler kommt mit – der hat schon seinen eigenen Pin
            let updated = players.filter { $0.id != ownPlayerId && MapPlayerFilter.isVisible(name: $0.name) }.compactMap { p -> PlayerAnnotation? in
                guard let lat = p.latitude, let lon = p.longitude else { return nil }
                return PlayerAnnotation(
                    playerId: p.id,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    title: "\(p.name) · \(p.rankName)",
                    rankName: p.rankName,
                    character: GameCharacter.from(serverId: p.character)
                )
            }
            // Spieler gleiten zur neuen Position statt zu springen
            withAnimation(.easeInOut(duration: 0.8)) { annotations = updated }
            announceArrivals(updated)

            if let me = players.first(where: { $0.id == ownPlayerId }) {
                ownPlayerName = me.name
            }
        } catch {
            print("Fehler beim Laden der Nearby Players", error)
        }
    }

    /// Spieler wieder in die Mitte, Zoom und Drehung bleiben.
    private func recenter(on coordinate: CLLocationCoordinate2D, keeping camera: MapCamera) {
        isFollowingUser = true
        isProgrammaticCameraUpdate = true
        withAnimation(.easeOut(duration: 0.3)) {
            position = .camera(MapCamera(centerCoordinate: coordinate, distance: camera.distance,
                                         heading: camera.heading, pitch: camera.pitch))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isProgrammaticCameraUpdate = false
        }
    }

    private func showTapMark(at location: CGPoint) {
        let mark = MapTapMark(location: location)
        mapTaps.append(mark)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            mapTaps.removeAll { $0.id == mark.id }
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

/// Eine Stelle, auf die getippt wurde.
struct MapTapMark: Identifiable {
    let id = UUID()
    let location: CGPoint
}

/// Welle an der getippten Stelle: Punkt + zwei Ringe, die sich ausbreiten und verblassen.
private struct MapTapRipple: View {
    @State private var expanded = false

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { ring in
                Circle()
                    .stroke(Color.challengrYellow, lineWidth: 3)
                    .frame(width: 70, height: 70)
                    .scaleEffect(expanded ? 1 : 0.15)
                    .opacity(expanded ? 0 : 0.9)
                    .animation(.easeOut(duration: 0.55).delay(Double(ring) * 0.12), value: expanded)
            }
            Circle()
                .fill(Color.challengrYellow)
                .frame(width: 12, height: 12)
                .shadow(color: .black.opacity(0.3), radius: 2)
                .scaleEffect(expanded ? 0.4 : 1)
                .opacity(expanded ? 0 : 1)
                .animation(.easeOut(duration: 0.6), value: expanded)
        }
        .onAppear { expanded = true }
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
