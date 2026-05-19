import Foundation
import Combine

@MainActor
final class FriendsInboxStore: ObservableObject {
    @Published private(set) var pendingIncomingCount: Int = 0
    @Published private(set) var lastBannerText: String? = nil

    private let friendsService = FriendsService()
    private let playerService = PlayerLocationService()

    private var pollTask: Task<Void, Never>? = nil

    func startPolling(playerId: String) {
        // Only start once
        if pollTask != nil { return }

        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.pollOnce(playerId: playerId)
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func pollOnce(playerId: String) async {
        do {
            let incoming = try await friendsService.loadIncomingPendingRequests(playerId: playerId)
            let newCount = incoming.count

            // If we went from 0 -> >0, create a one-time banner text.
            if pendingIncomingCount == 0 && newCount > 0 {
                if let first = incoming.first, let dto = try? await playerService.loadPlayerById(id: first.fromPlayerId) {
                    lastBannerText = "Neue Freundschaftsanfrage von \(dto.name)"
                } else {
                    lastBannerText = "Neue Freundschaftsanfrage"
                }
            }

            pendingIncomingCount = newCount
        } catch {
            // best-effort polling
        }
    }

    func consumeBanner() {
        lastBannerText = nil
    }
}
