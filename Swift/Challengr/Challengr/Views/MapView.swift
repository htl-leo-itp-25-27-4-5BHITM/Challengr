import SwiftUI
import MapKit
import CoreLocation
import CoreLocationUI
import Combine
import UIKit

struct PlayerAnnotation: Identifiable {
    let id = UUID()
    let playerId: Int64
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct MapView: View {
    @StateObject private var locationHelper = LocationHelper()
    private let playerService = PlayerLocationService()
    private let challengesService = ChallengesService()

    // Eigener Spieler
    let ownPlayerId: Int64 = 1

    // WebSocket
    @StateObject private var socket = GameSocketService(playerId: 1)
    @State private var incomingChallenge: (
        battleId: Int64,
        fromId: Int64,
        challengeId: Int64,
        name: String,
        category: String
    )? = nil

    @State private var currentBattleId: Int64? = nil
    @State private var isBattleActive = false
    @State private var activeBattleInfo: (challengeName: String,
                                          category: String,
                                          playerA: String,
                                          playerB: String)? = nil
    @State private var ownPlayerName: String = ""

    // Eigene Position
    @State private var ownCoordinate: CLLocationCoordinate2D? = nil

    private let startCoordinate = CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738)

    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
            distance: 1000,
            heading: 0,
            pitch: 0
        )
    )

    // Zoom-Grenzen
    let minDistance: CLLocationDistance = 200
    let maxDistance: CLLocationDistance = 5000

    @State private var annotations: [PlayerAnnotation] = []
    @State private var showChallengeView = false

    @State private var selectedPlayer: PlayerAnnotation? = nil
    @State private var showPlayerPopup = false
    @State private var showPlayerChallengeDialog = false

    @State private var allChallenges: [ChallengesService.Challenge] = []
    
    
    
    // 🔽 Challenge-Text + Kategorie-Name zu einer Challenge-ID finden
    private func challengeInfo(for id: Int64) -> (name: String, category: String) {
        if let ch = allChallenges.first(where: { Int64($0.id) == id }) {
            return (ch.text, ch.challengeCategory.name)
        } else {
            return ("Challenge \(id)", "Unbekannt")
        }
    }

    
    private func vibrate() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            mapLayer
            locationButton
            challengeButton
        }
        .overlay(playerPopupOverlay)
        .overlay(challengeDialogOverlay)
        .overlay(incomingChallengeOverlay)
        .sheet(isPresented: $showChallengeView) {
            challengeSheet
        }
        .fullScreenCover(isPresented: $isBattleActive) {
            battleScreen
        }
    }

    // MARK: - Teil-Views

    private var mapLayer: some View {
        Map(
            position: $position,
            bounds: MapCameraBounds(
                minimumDistance: minDistance,
                maximumDistance: maxDistance
            )
        ) {
            // 200m Radius um eigenen Spieler
            if let ownCoordinate {
                MapCircle(center: ownCoordinate, radius: 200)
                    .foregroundStyle(Color.blue.opacity(0.2))
                    .stroke(Color.blue.opacity(0.6), lineWidth: 2)
            }

            // Andere Spieler
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
        .onReceive(locationHelper.$userLocation, perform: handleLocation)
    }

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

    private var challengeButton: some View {
        VStack {
            Spacer()
            Button {
                showChallengeView = true
            } label: {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .background(Color.challengrYellow)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
    }

    private var playerPopupOverlay: some View {
        Group {
            if let player = selectedPlayer, showPlayerPopup {
                VStack {
                    Text("\(player.title)\nherausfordern")
                        .font(.headline)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .onTapGesture {
                            showPlayerChallengeDialog = true
                        }
                }
                .padding(.top, 80)
                .transition(.scale)
            }
        }
    }

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

    private var incomingChallengeOverlay: some View {
        Group {
            if let challenge = incomingChallenge,
               let battleId = currentBattleId {

                let opponentName =
                    annotations.first(where: { $0.playerId == challenge.fromId })?.title
                    ?? "Gegner \(challenge.fromId)"

                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        Text("Du wurdest herausgefordert!")
                            .font(.headline)

                        Text("Von \(opponentName)\nChallenge: \(challenge.name)")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)

                        HStack {
                            Button("Annehmen") {
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
                                currentBattleId = nil
                                isBattleActive = true
                            }
                            .padding(.horizontal)

                            Button("Ablehnen") {
                                socket.sendUpdateBattleStatus(
                                    battleId: battleId,
                                    status: "DECLINED"
                                )

                                incomingChallenge = nil
                                currentBattleId = nil
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .padding()
                }
                .transition(.scale)
            }
        }
    }

    private var challengeSheet: some View {
        ChallengeView()
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
    }

    private var battleScreen: some View {
        Group {
            if let info = activeBattleInfo {
                BattleView(
                    challengeName: info.challengeName,
                    category: info.category,
                    playerLeft: info.playerA,
                    playerRight: info.playerB
                ) {
                    isBattleActive = false
                }
            }
        }
    }


    // MARK: - Logik

    private func setupSocket() {
        socket.connect()

        // 🔽 Challenges aller Kategorien einmalig vorladen
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

        socket.onChallengeReceived = { battleId, fromId, toId, challengeId in
            if toId == ownPlayerId {
                // 🔽 Jetzt dynamisch aus dem Cache holen
                let info = challengeInfo(for: challengeId)

                incomingChallenge = (
                    battleId: battleId,
                    fromId: fromId,
                    challengeId: challengeId,
                    name: info.name,
                    category: info.category
                )
                currentBattleId = battleId
            }
        }
    }


    private func handleLocation(_ userLoc: CLLocationCoordinate2D?) {
        guard let userLoc = userLoc else { return }

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
                        title: $0.name
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
