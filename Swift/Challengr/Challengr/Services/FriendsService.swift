import Foundation

struct FriendRequestCreateDTO: Codable {
    let fromPlayerId: String
    let toPlayerId: String
}

struct FriendRequestDTO: Decodable, Identifiable {
    let id: Int64
    let fromPlayerId: String
    let toPlayerId: String
    let status: String
    let createdAt: String
}

struct FriendDTO: Decodable {
    let playerId: String
}

struct FriendGiftCreateDTO: Codable {
    let fromPlayerId: String
    let toPlayerId: String
    /// Eigenen Sticker verschenken statt Zufalls-Geschenk
    var stickerId: String? = nil
}

struct FriendGiftDTO: Decodable, Identifiable {
    let id: Int64
    let fromPlayerId: String
    let toPlayerId: String
    let status: String
    let createdAt: String
    let claimedAt: String?
    /// Sticker, der drin war (erst nach dem Öffnen)
    var stickerId: String? = nil
    /// Vom Absender ausgesucht (statt Zufall)
    var fromCollection: Bool? = nil
}

enum GiftError: LocalizedError {
    case alreadySentToday
    case noStickerLeft

    var errorDescription: String? {
        switch self {
        case .alreadySentToday: return "Heute hast du diesem Freund schon ein Geschenk geschickt – morgen wieder."
        case .noStickerLeft: return "Von diesem Sticker hast du gerade keinen mehr."
        }
    }
}

final class FriendsService {
    private let baseURL = BackendConfig.apiURL("api/friends")

    func sendFriendRequest(from fromPlayerId: String, to toPlayerId: String) async throws {
        let url = baseURL.appendingPathComponent("requests")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            FriendRequestCreateDTO(fromPlayerId: fromPlayerId, toPlayerId: toPlayerId)
        )

        let (_, response) = try await API.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    /// Spieler per Namen finden (ab 2 Zeichen, ohne Standort).
    func searchPlayers(query: String) async throws -> [PlayerDTO] {
        var components = URLComponents(url: BackendConfig.apiURL("api/players/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else { return [] }
        let (data, _) = try await API.data(from: url)
        return try JSONDecoder().decode([PlayerDTO].self, from: data)
    }

    func loadOutgoingPendingRequests(playerId: String) async throws -> [FriendRequestDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("requests/outgoing"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "playerId", value: playerId)]
        guard let url = components.url else { return [] }

        let (data, _) = try await API.data(from: url)
        return try JSONDecoder().decode([FriendRequestDTO].self, from: data)
    }

    func loadIncomingPendingRequests(playerId: String) async throws -> [FriendRequestDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("requests/incoming"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "playerId", value: playerId)]
        guard let url = components.url else { return [] }

        let (data, _) = try await API.data(from: url)
        return try JSONDecoder().decode([FriendRequestDTO].self, from: data)
    }

    func acceptRequest(requestId: Int64) async throws {
        let url = baseURL
            .appendingPathComponent("requests")
            .appendingPathComponent(String(requestId))
            .appendingPathComponent("accept")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await API.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    func declineRequest(requestId: Int64) async throws {
        let url = baseURL
            .appendingPathComponent("requests")
            .appendingPathComponent(String(requestId))
            .appendingPathComponent("decline")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await API.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    func loadFriends(playerId: String) async throws -> [FriendDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("list"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "playerId", value: playerId)]
        guard let url = components.url else { return [] }

        let (data, _) = try await API.data(from: url)
        return try JSONDecoder().decode([FriendDTO].self, from: data)
    }

    func removeFriend(playerId: String, friendId: String) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("remove"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "playerId", value: playerId),
            URLQueryItem(name: "friendId", value: friendId)
        ]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await API.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    /// stickerId: eigenen Sticker verschenken (kostet einen, ohne Tages-Grenze); nil = Zufalls-Geschenk
    func sendGift(from fromPlayerId: String, to toPlayerId: String, stickerId: String? = nil) async throws {
        let url = baseURL.appendingPathComponent("gifts")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            FriendGiftCreateDTO(fromPlayerId: fromPlayerId, toPlayerId: toPlayerId, stickerId: stickerId)
        )

        let (_, response) = try await API.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw GiftError.alreadySentToday
        }
        if let http = response as? HTTPURLResponse, http.statusCode == 409 {
            throw GiftError.noStickerLeft
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    func loadIncomingGifts(playerId: String) async throws -> [FriendGiftDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("gifts/incoming"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "playerId", value: playerId)]
        guard let url = components.url else { return [] }

        let (data, _) = try await API.data(from: url)
        return try JSONDecoder().decode([FriendGiftDTO].self, from: data)
    }

    /// Öffnet das Geschenk; gibt das geöffnete Geschenk (mit Sticker) zurück
    func claimGift(giftId: Int64, playerId: String) async throws -> FriendGiftDTO? {
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("gifts")
                .appendingPathComponent(String(giftId))
                .appendingPathComponent("claim"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "playerId", value: playerId)]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await API.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try? JSONDecoder().decode(FriendGiftDTO.self, from: data)
    }
}
