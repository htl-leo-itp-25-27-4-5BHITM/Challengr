import Foundation

/// Eine Figur mit Freischalt-Stand für den eigenen Spieler (vom Backend).
struct CharacterUnlockDTO: Codable, Equatable {
    let id: String
    let name: String
    /// NONE, WINS, KNOWLEDGE_WINS, CHECKINS, POINTS
    let requirement: String
    let required: Int
    let progress: Int
    let unlocked: Bool
    let selected: Bool
}

enum CharacterServiceError: LocalizedError {
    /// statusCode 403 = Figur gesperrt, 400 = unbekannt, 404 = alter Server ohne Figuren-API
    case rejected(String, statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .rejected(let message, _): return message
        }
    }

    var isLocked: Bool {
        if case .rejected(_, let code) = self { return code == 403 }
        return false
    }
}

/// Figurenwahl und Freischaltungen über `api/players/{id}/characters` bzw. `/character`.
final class CharacterService {
    private let baseURL = BackendConfig.apiURL("api/players")

    func loadCharacters(playerId: String) async throws -> [CharacterUnlockDTO] {
        let url = baseURL.appendingPathComponent(playerId).appendingPathComponent("characters")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([CharacterUnlockDTO].self, from: data)
    }

    /// Speichert die Figur am Server. Gesperrte oder unbekannte Figuren lehnt der Server ab.
    func selectCharacter(playerId: String, character: GameCharacter) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(playerId).appendingPathComponent("character"))
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["character": character.rawValue])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8).flatMap { $0.isEmpty ? nil : $0 }
            throw CharacterServiceError.rejected(message ?? "Figur konnte nicht gespeichert werden (\(http.statusCode))",
                                                 statusCode: http.statusCode)
        }
    }
}

/// Merkt sich, welche Figuren schon freigeschaltet waren – für den "freigeschaltet!"-Hinweis.
enum CharacterUnlockTracker {
    static let key = "knownUnlockedCharacters"

    /// Neu freigeschaltete Figuren seit dem letzten Aufruf. Beim allerersten Mal: keine.
    static func newlyUnlocked(_ unlocks: [CharacterUnlockDTO], defaults: UserDefaults = .standard) -> [GameCharacter] {
        let now = Set(unlocks.filter(\.unlocked).map(\.id))
        defer { defaults.set(Array(now), forKey: key) }
        guard let known = defaults.stringArray(forKey: key) else { return [] }
        return now.subtracting(known).sorted().compactMap(GameCharacter.from(serverId:))
    }
}
