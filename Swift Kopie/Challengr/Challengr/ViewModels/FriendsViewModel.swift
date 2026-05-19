import Foundation
import CoreLocation
import Combine

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var nearbyPlayers: [PlayerDTO] = []
    @Published var pendingOutgoingToPlayerIds: Set<String> = []
    @Published var isLoadingNearby = false
    @Published var errorText: String? = nil

    @Published var incomingRequest: FriendRequestDTO? = nil
    private var lastSeenIncomingRequestId: Int64? = nil

    private let playerService = PlayerLocationService()
    private let friendsService = FriendsService()

    func loadNearby(ownPlayerId: String, coordinate: CLLocationCoordinate2D, radiusMeters: Double) async {
        isLoadingNearby = true
        errorText = nil
        defer { isLoadingNearby = false }

        do {
            let players = try await playerService.loadNearbyPlayers(
                currentPlayerId: ownPlayerId,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radius: radiusMeters
            )
            nearbyPlayers = players

            let outgoing = try await friendsService.loadOutgoingPendingRequests(playerId: ownPlayerId)
            pendingOutgoingToPlayerIds = Set(outgoing.map { $0.toPlayerId })

            // Also check incoming once on load (used to show popup)
            await pollIncomingOnce(playerId: ownPlayerId)
        } catch {
            errorText = "Fehler beim Laden: \(error.localizedDescription)"
        }
    }

    func sendRequest(ownPlayerId: String, to playerId: String) async {
        errorText = nil
        guard !pendingOutgoingToPlayerIds.contains(playerId) else { return }

        do {
            try await friendsService.sendFriendRequest(from: ownPlayerId, to: playerId)
            pendingOutgoingToPlayerIds.insert(playerId)
        } catch {
            errorText = "Konnte Anfrage nicht senden: \(error.localizedDescription)"
        }
    }

    func pollIncomingOnce(playerId: String) async {
        do {
            let incoming = try await friendsService.loadIncomingPendingRequests(playerId: playerId)

            // If there's a new request we haven't shown yet, surface it.
            if let newest = incoming.first {
                if lastSeenIncomingRequestId != newest.id {
                    lastSeenIncomingRequestId = newest.id
                    incomingRequest = newest
                }
            }
        } catch {
            // Don't surface as fatal error; this is best-effort.
            print("Incoming friend requests poll failed:", error)
        }
    }
}
