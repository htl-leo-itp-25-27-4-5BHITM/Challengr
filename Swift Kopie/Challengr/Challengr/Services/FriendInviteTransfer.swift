import Foundation
import Combine
import UniformTypeIdentifiers

enum FriendInviteImportError: LocalizedError {
    case invalidPayload
    case unreadablePayload

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Ungültige Challengr-Einladung."
        case .unreadablePayload:
            return "Die Einladung konnte nicht gelesen werden."
        }
    }
}

enum FriendInviteTransfer {
    static let typeIdentifier = "at.htl.leonding.challengr.friend-invite"
    static let fileExtension = "challengrfriend"

    static func makeTemporaryInviteFile(fromPlayerId: String) throws -> URL {
        let payload = FriendInvitePayload.v1(fromPlayerId: fromPlayerId).asURLString()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("friend-invite-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)

        try Data(payload.utf8).write(to: url, options: .atomic)
        return url
    }
}

enum FriendInvitePayload {
    case v1(fromPlayerId: String)

    func asURLString() -> String {
        switch self {
        case .v1(let fromPlayerId):
            var components = URLComponents()
            components.scheme = "challengr"
            components.host = "friend-invite"
            components.queryItems = [
                URLQueryItem(name: "from", value: fromPlayerId)
            ]
            return components.string ?? "challengr://friend-invite?from=\(fromPlayerId)"
        }
    }

    static func parse(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if !trimmed.contains("://"), !trimmed.contains("/") {
            return trimmed
        }

        guard let url = URL(string: trimmed) else { return nil }

        if let scheme = url.scheme?.lowercased(), scheme != "challengr" {
            return nil
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let from = components.queryItems?.first(where: { $0.name == "from" || $0.name == "playerId" })?.value,
           !from.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return from
        }

        let pathCandidate = url.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !pathCandidate.isEmpty {
            return pathCandidate
        }

        return nil
    }

    static func parseIncomingURL(_ url: URL) throws -> String {
        if url.isFileURL {
            return try parseImportedFile(url)
        }

        if let fromPlayerId = parse(url.absoluteString) {
            return fromPlayerId
        }

        throw FriendInviteImportError.invalidPayload
    }

    private static func parseImportedFile(_ url: URL) throws -> String {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let payload = try? String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !payload.isEmpty
        else {
            throw FriendInviteImportError.unreadablePayload
        }

        guard let fromPlayerId = parse(payload) else {
            throw FriendInviteImportError.invalidPayload
        }

        return fromPlayerId
    }
}

@MainActor
final class FriendInviteFlow: ObservableObject {
    @Published var alertMessage: String? = nil

    private let friendsService = FriendsService()
    private var pendingFromPlayerId: String? = nil

    func receive(url: URL, ownPlayerId: String?) async {
        do {
            let fromPlayerId = try FriendInvitePayload.parseIncomingURL(url)
            await handleInvite(fromPlayerId: fromPlayerId, ownPlayerId: ownPlayerId)
        } catch {
            alertMessage = (error as? LocalizedError)?.errorDescription ?? "Einladung konnte nicht verarbeitet werden."
        }
    }

    func resumePendingInvite(ownPlayerId: String?) async {
        guard let pendingFromPlayerId else { return }
        await handleInvite(fromPlayerId: pendingFromPlayerId, ownPlayerId: ownPlayerId)
    }

    func clearAlert() {
        alertMessage = nil
    }

    private func handleInvite(fromPlayerId: String, ownPlayerId: String?) async {
        guard let ownPlayerId, !ownPlayerId.isEmpty else {
            pendingFromPlayerId = fromPlayerId
            alertMessage = "Einladung empfangen. Nach dem Login wird die Freundschaftsanfrage gesendet."
            return
        }

        guard fromPlayerId != ownPlayerId else {
            pendingFromPlayerId = nil
            alertMessage = "Das ist deine eigene Einladung."
            return
        }

        do {
            try await friendsService.sendFriendRequest(from: ownPlayerId, to: fromPlayerId)
            pendingFromPlayerId = nil
            alertMessage = "Freundschaftsanfrage wurde gesendet."
        } catch {
            pendingFromPlayerId = fromPlayerId
            alertMessage = "Einladung empfangen, aber die Anfrage konnte nicht gesendet werden."
        }
    }
}

extension UTType {
    static var challengrFriendInvite: UTType {
        UTType(exportedAs: FriendInviteTransfer.typeIdentifier)
    }
}