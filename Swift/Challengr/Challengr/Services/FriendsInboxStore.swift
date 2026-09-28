//
//  FriendsInboxStore.swift
//  Challengr
//

import Foundation
import Combine

/// Keeps track of incoming friend requests for the map (Banner + Zähler am Profil-Button).
/// Updates come live via WebSocket; a slow poll is only a fallback if an event was missed.
@MainActor
final class FriendsInboxStore: ObservableObject {
    @Published private(set) var pendingIncomingCount: Int = 0
    @Published private(set) var lastBannerText: String? = nil

    private let friendsService = FriendsService()
    private let playerService = PlayerLocationService()

    private var ownPlayerId: String?
    private var fallbackPollTask: Task<Void, Never>? = nil

    func start(playerId: String) {
        ownPlayerId = playerId
        guard fallbackPollTask == nil else { return }

        fallbackPollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshCount()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60s
            }
        }
    }

    func stop() {
        fallbackPollTask?.cancel()
        fallbackPollTask = nil
    }

    /// WebSocket: "friend-request-created"
    func handleRequestCreated(fromId: String, toId: String) {
        guard let ownPlayerId, toId == ownPlayerId, fromId != ownPlayerId else { return }

        Task {
            let name = await playerName(for: fromId)
            let text = name.map { "Neue Freundschaftsanfrage von \($0)" } ?? "Neue Freundschaftsanfrage"
            lastBannerText = text
            SoundManager.shared.play(.friendRequest)
            NotificationManager.shared.notifyIfInBackground(title: "Challengr", body: text)
            await refreshCount()
        }
    }

    /// WebSocket: "friend-request-updated" (ACCEPTED / DECLINED)
    func handleRequestUpdated(fromId: String, toId: String, status: String) {
        guard let ownPlayerId else { return }

        // Our own outgoing request was accepted -> let the sender know.
        if fromId == ownPlayerId, status.uppercased() == "ACCEPTED" {
            Task {
                let name = await playerName(for: toId)
                let text = name.map { "\($0) hat deine Anfrage angenommen" } ?? "Freundschaftsanfrage angenommen"
                lastBannerText = text
                SoundManager.shared.play(.friendAccepted)
                NotificationManager.shared.notifyIfInBackground(title: "Challengr", body: text)
            }
        }

        if toId == ownPlayerId || fromId == ownPlayerId {
            Task { await refreshCount() }
        }
    }

    func consumeBanner() {
        lastBannerText = nil
    }

    func refreshCount() async {
        guard let ownPlayerId else { return }
        do {
            let incoming = try await friendsService.loadIncomingPendingRequests(playerId: ownPlayerId)
            pendingIncomingCount = incoming.count
        } catch {
            // best effort – next event or poll fixes it
        }
    }

    private func playerName(for playerId: String) async -> String? {
        try? await playerService.loadPlayerById(id: playerId).name
    }
}
