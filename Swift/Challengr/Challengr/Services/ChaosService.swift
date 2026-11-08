import SwiftUI

/// Chaos-Stunde: einmal am Tag eine Stunde lang eine verrückte Regel (Backend: `control.ChaosService`, `/api/chaos`).
struct ChaosStatus: Codable, Equatable {
    let active: Bool
    var rule: String? = nil
    var title: String? = nil
    var description: String? = nil
    /// ISO-8601, z. B. "2026-11-08T16:42:00Z"
    var endsAt: String? = nil

    static let off = ChaosStatus(active: false)

    /// Riesen-Stunde: Figuren auf der Karte groß
    var giants: Bool { active && rule == "GIANTS" }

    var endDate: Date? { endsAt.flatMap { ISO8601DateFormatter.chaos.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) } }

    /// "noch 37 min" (nil ohne Ende)
    func remainingText(now: Date = Date()) -> String? {
        guard let end = endDate else { return nil }
        let minutes = max(0, Int(ceil(end.timeIntervalSince(now) / 60)))
        return "noch \(minutes) min"
    }
}

extension ISO8601DateFormatter {
    /// Java `Instant.toString()` – mit und ohne Sekundenbruchteile
    static let chaos: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

final class ChaosService {
    func load() async throws -> ChaosStatus {
        let (data, response) = try await API.data(from: BackendConfig.apiURL("api/chaos"))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return .off }
        return try JSONDecoder().decode(ChaosStatus.self, from: data)
    }
}

/// Leiste oben auf der Karte, solange die Chaos-Stunde läuft.
struct ChaosChip: View {
    let status: ChaosStatus
    let now: Date

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .foregroundColor(.challengrYellow)
            Text("CHAOS · \((status.title ?? "").uppercased())")
            if let remaining = status.remainingText(now: now) {
                Text(remaining)
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .font(.system(size: 12, weight: .black, design: .rounded))
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(LinearGradient(colors: [Color(red: 0.45, green: 0.1, blue: 0.85), Color(red: 0.85, green: 0.1, blue: 0.5)],
                                                  startPoint: .leading, endPoint: .trailing)))
        .shadow(color: Color.purple.opacity(0.6), radius: 8)
        .accessibilityElement(children: .combine)
    }
}
