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

        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    func loadOutgoingPendingRequests(playerId: String) async throws -> [FriendRequestDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("requests/outgoing"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "playerId", value: playerId)]
        guard let url = components.url else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([FriendRequestDTO].self, from: data)
    }

    func loadIncomingPendingRequests(playerId: String) async throws -> [FriendRequestDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("requests/incoming"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "playerId", value: playerId)]
        guard let url = components.url else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([FriendRequestDTO].self, from: data)
    }

    func acceptRequest(requestId: Int64) async throws {
        let url = baseURL
            .appendingPathComponent("requests")
            .appendingPathComponent(String(requestId))
            .appendingPathComponent("accept")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await URLSession.shared.data(for: request)
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

        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    func loadFriends(playerId: String) async throws -> [FriendDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("list"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "playerId", value: playerId)]
        guard let url = components.url else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
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

        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }
}
