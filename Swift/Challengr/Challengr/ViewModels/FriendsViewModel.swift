import Foundation
import CoreLocation
import Combine

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [PlayerDTO] = []
    @Published var nearbyPlayers: [PlayerDTO] = []
    @Published var pendingOutgoingToPlayerIds: Set<String> = []
    @Published var isLoadingNearby = false
    @Published var errorText: String? = nil

    private let playerService = PlayerLocationService()
    private let friendsService = FriendsService()

    // Keep the last used inputs so we can refresh after actions (accept/remove/send)
    private var lastOwnPlayerId: String? = nil
    private var lastCoordinate: CLLocationCoordinate2D? = nil
    private var lastRadiusMeters: Double? = nil

    func loadAll(ownPlayerId: String, coordinate: CLLocationCoordinate2D, radiusMeters: Double) async {
        isLoadingNearby = true
        errorText = nil
        defer { isLoadingNearby = false }

        lastOwnPlayerId = ownPlayerId
        lastCoordinate = coordinate
        lastRadiusMeters = radiusMeters

        do {
            // Friends
            let friendIds = try await friendsService.loadFriends(playerId: ownPlayerId).map { $0.playerId }
            var friendDTOs: [PlayerDTO] = []
            for id in friendIds {
                if let dto = try? await playerService.loadPlayerById(id: id) {
                    friendDTOs.append(dto)
                }
            }
            friends = friendDTOs

            let friendIdSet = Set(friendDTOs.map { $0.id })

            let players = try await playerService.loadNearbyPlayers(
                currentPlayerId: ownPlayerId,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radius: radiusMeters
            )
            // Exclude already-friended players from the nearby suggestions.
            nearbyPlayers = players.filter { !friendIdSet.contains($0.id) }

            let outgoing = try await friendsService.loadOutgoingPendingRequests(playerId: ownPlayerId)
            pendingOutgoingToPlayerIds = Set(outgoing.map { $0.toPlayerId })
        } catch {
            errorText = "Fehler beim Laden: \(error.localizedDescription)"
        }
    }

    func removeFriend(ownPlayerId: String, friendId: String) async {
        errorText = nil
        do {
            try await friendsService.removeFriend(playerId: ownPlayerId, friendId: friendId)
            friends.removeAll(where: { $0.id == friendId })
            // Refresh so nearby list updates immediately.
            await refreshIfPossible()
        } catch {
            errorText = "Konnte Freund nicht entfernen: \(error.localizedDescription)"
        }
    }

    func sendRequest(ownPlayerId: String, to playerId: String) async {
        errorText = nil
        guard !pendingOutgoingToPlayerIds.contains(playerId) else { return }

        do {
            try await friendsService.sendFriendRequest(from: ownPlayerId, to: playerId)
            pendingOutgoingToPlayerIds.insert(playerId)
            // Refresh outgoing state (in case backend already had a request)
            await refreshIfPossible()
        } catch {
            errorText = "Konnte Anfrage nicht senden: \(error.localizedDescription)"
        }
    }

    private func refreshIfPossible() async {
        guard let pid = lastOwnPlayerId,
              let coord = lastCoordinate,
              let radius = lastRadiusMeters else { return }

        await loadAll(ownPlayerId: pid, coordinate: coord, radiusMeters: radius)
    }
}
