import SwiftUI
import MapKit
import CoreLocation
import CoreLocationUI
import Combine
import UIKit

struct PlayerAnnotation: Identifiable {
    let id = UUID()
    let playerId: Int64                     // ✅ echte Spieler-ID
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct MapView: View {
    @StateObject private var locationHelper = LocationHelper()
    private let playerService = PlayerLocationService()

    // Eigener Spieler (muss zu deiner DB passen)
    let ownPlayerId: Int64 = 1

    // WebSocket für diesen Spieler
    @StateObject private var socket = GameSocketService(playerId: 1)
    @State private var incomingChallenge: (battleId: Int64, fromId: Int64, challengeId: Int64)? = nil
    
    // Startposition
    private let startCoordinate = CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738)

    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
            distance: 1000,
            heading: 0,
            pitch: 0
        )
    )

    // Harte Zoom-Grenzen in Metern
    let minDistance: CLLocationDistance = 200
    let maxDistance: CLLocationDistance = 5000

    @State private var annotations: [PlayerAnnotation] = []
    @State private var showChallengeView = false

    @State private var selectedPlayer: PlayerAnnotation? = nil
    @State private var showPlayerPopup = false
    @State private var showPlayerChallengeDialog = false

    private func vibrate() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            Map(
                position: $position,
                bounds: MapCameraBounds(
                    minimumDistance: minDistance,
                    maximumDistance: maxDistance
                )
            ) {
                ForEach(annotations) { annotation in
                    Annotation(annotation.title, coordinate: annotation.coordinate) {
                        Button {
                            if selectedPlayer?.id == annotation.id {
                                // erneuter Klick auf den gleichen Spieler → Popup schließen
                                showPlayerPopup.toggle()
                            } else {
                                // neuer Spieler → Popup anzeigen
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
            .onAppear {
                // WebSocket verbinden
                socket.connect()
              
                socket.onChallengeReceived = { battleId, fromId, toId, challengeId in
                    print("📥 battle-requested: battle \(battleId), \(fromId) -> \(toId), Challenge \(challengeId)")
                    if toId == ownPlayerId {
                        incomingChallenge = (battleId: battleId, fromId: fromId, challengeId: challengeId)
                    }
                }

            }

            .onReceive(locationHelper.$userLocation) { userLoc in
                guard let userLoc = userLoc else { return }

                // Kamera folgt dem Nutzer – Zoom wird durch bounds hart begrenzt
                position = .camera(
                    MapCamera(
                        centerCoordinate: userLoc,
                        distance: 1000,   // MapCameraBounds clamped das auf 200–5000
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

                        let newAnnotations = players.map { player in
                            PlayerAnnotation(
                                playerId: player.id,   // ✅ ID vom Backend
                                coordinate: CLLocationCoordinate2D(
                                    latitude: player.latitude,
                                    longitude: player.longitude
                                ),
                                title: player.name
                            )
                        }

                        annotations = newAnnotations
                        if players.count > 0 {
                            print("Mehrere Spieler gefunden: \(players.count)")
                            vibrate()
                        }
                    } catch {
                        print("Fehler beim Laden der Nearby Players: \(error)")
                    }
                }
            }

            LocationButton(.currentLocation) {
                position = .userLocation(
                    followsHeading: false,
                    fallback: .camera(
                        MapCamera(
                            centerCoordinate: startCoordinate,
                            distance: 1000,   // wird ebenfalls durch bounds begrenzt
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

        .overlay {
            if let player = selectedPlayer, showPlayerPopup {
                VStack {
                    Text("\(player.title)\nherausfordern")
                        .font(.headline)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .onTapGesture {
                            // Öffnet das größere Challenge Dialog
                            showPlayerChallengeDialog = true
                        }
                }
                .padding(.top, 80)
                .transition(.scale)
            }
        }

        .overlay {
            if let player = selectedPlayer, showPlayerChallengeDialog {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showPlayerChallengeDialog = false
                        }

                    ChallengeDialogView(
                        otherPlayerId: player.playerId,   // ✅ echte ID
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

        .overlay {
            if let challenge = incomingChallenge {
                VStack(spacing: 12) {
                    Text("Du wurdest herausgefordert!")
                        .font(.headline)
                    Text("Von Spieler-ID \(challenge.fromId)\nChallenge-ID \(challenge.challengeId)")
                        .multilineTextAlignment(.center)
                        .font(.subheadline)

                    HStack {
                        Button("Annehmen") {
                            // TODO: z.B. Battle-Status an Server schicken
                            incomingChallenge = nil
                        }
                        .padding(.horizontal)

                        Button("Ablehnen") {
                            incomingChallenge = nil
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
        }

        
        .sheet(isPresented: $showChallengeView) {
            ChallengeView()
                .presentationDetents([ .medium ])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
    }
}
