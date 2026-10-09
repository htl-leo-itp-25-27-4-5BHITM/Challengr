import Foundation

/// Melden und Blockieren (Apple-Regel 1.2). Der Server setzt Blockierungen überall durch.
struct BlockedPlayerDTO: Codable, Identifiable, Equatable {
    let id: String
    let name: String
}

enum ReportReason: String, CaseIterable, Identifiable {
    case beleidigung = "BELEIDIGUNG"
    case unpassenderName = "UNPASSENDER_NAME"
    case belaestigung = "BELAESTIGUNG"
    case betrug = "BETRUG"
    case sonstiges = "SONSTIGES"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beleidigung:     return "Beleidigung"
        case .unpassenderName: return "Unpassender Name"
        case .belaestigung:    return "Belästigung / Verfolgen"
        case .betrug:          return "Schummeln / Betrug"
        case .sonstiges:       return "Etwas anderes"
        }
    }
}

final class SafetyService {
    private let baseURL = BackendConfig.apiURL("api/safety")

    func block(playerId: String) async throws {
        try await send("POST", path: "blocks/\(playerId)")
    }

    func unblock(playerId: String) async throws {
        try await send("DELETE", path: "blocks/\(playerId)")
    }

    func blockedPlayers() async throws -> [BlockedPlayerDTO] {
        let (data, _) = try await API.data(from: baseURL.appendingPathComponent("blocks"))
        return try JSONDecoder().decode([BlockedPlayerDTO].self, from: data)
    }

    func report(playerId: String, reason: ReportReason, comment: String) async throws {
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        var body: [String: String] = ["reason": reason.rawValue]
        if !trimmed.isEmpty { body["comment"] = String(trimmed.prefix(500)) }
        try await send("POST", path: "reports/\(playerId)", json: body)
    }

    private func send(_ method: String, path: String, json: [String: String]? = nil) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        let (_, response) = try await API.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, (200...299).contains(status) else {
            throw URLError(.badServerResponse)
        }
    }
}
