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

    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
            distance: 1000,
            heading: 0,
            pitch: 0
        )
    )

    @State private var annotations: [PlayerAnnotation] = []
    @State private var showChallengeView = false

    let ownPlayerId: Int64 = 1

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            Map(position: $position) {
                ForEach(annotations) { annotation in
                    Marker(annotation.title, coordinate: annotation.coordinate)
                        .tint(.chalengrRed)
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
                            centerCoordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
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
        .sheet(isPresented: $showChallengeView) {
            ChallengeView()
                .presentationDetents([ .medium ])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
    }
}
