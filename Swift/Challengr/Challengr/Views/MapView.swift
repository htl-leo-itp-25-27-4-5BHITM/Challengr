import SwiftUI
import MapKit
import CoreLocation
import CoreLocationUI
import Combine

struct PlayerAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct MapView: View {
    @StateObject private var locationHelper = LocationHelper()
    private let playerService = PlayerLocationService()

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


    let ownPlayerId: Int64 = 1

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
                                coordinate: CLLocationCoordinate2D(
                                    latitude: player.latitude,
                                    longitude: player.longitude
                                ),
                                title: player.name
                            )
                        }

                        annotations = newAnnotations
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
                    Text(player.title)
                        .font(.headline)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .onTapGesture {
                            showPlayerPopup = false
                        }
                }
                .padding(.top, 80)
                .transition(.scale)
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
