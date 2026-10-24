import Foundation

/// Grund beim Melden einer Quizfrage (wie am Server: QuizReport.Reason).
enum QuizReportReason: String, CaseIterable, Identifiable {
    case falscheAntwort = "FALSCHE_ANTWORT"
    case unklar = "UNKLAR"
    case tippfehler = "TIPPFEHLER"
    case sonstiges = "SONSTIGES"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .falscheAntwort: return "Die richtige Antwort stimmt nicht"
        case .unklar: return "Frage ist unklar"
        case .tippfehler: return "Tippfehler"
        case .sonstiges: return "Etwas anderes"
        }
    }
}

/// Ankündigung aus dem Dashboard (z. B. „Halloween-Event startet morgen!“).
struct AppAnnouncement: Decodable, Equatable {
    let id: Int64
    let text: String
}

/// Kleine Server-Aufrufe für Inhalte aus dem Dashboard.
final class AppContentService {
    func reportQuestion(id: Int64, reason: QuizReportReason) async throws {
        var request = URLRequest(url: BackendConfig.apiURL("api/quiz/questions/\(id)/report"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["reason": reason.rawValue])
        let (_, response) = try await API.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    /// Aktuelle Ankündigung oder nil (204 = keine).
    func currentAnnouncement() async throws -> AppAnnouncement? {
        let (data, response) = try await API.data(from: BackendConfig.apiURL("api/announcement"))
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else { return nil }
        return try JSONDecoder().decode(AppAnnouncement.self, from: data)
    }
}

/// Jede Ankündigung nur einmal zeigen.
enum AnnouncementMemory {
    static let key = "seenAnnouncementId"

    static func isNew(_ a: AppAnnouncement, defaults: UserDefaults = .standard) -> Bool {
        (defaults.object(forKey: key) as? Int64 ?? -1) != a.id
    }

    static func markSeen(_ a: AppAnnouncement, defaults: UserDefaults = .standard) {
        defaults.set(a.id, forKey: key)
    }
}
