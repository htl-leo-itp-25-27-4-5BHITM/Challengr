import SwiftUI

/// Erzfeind: der meistgespielte Gegner (ab 3 Battles) mit Bilanz – vom Backend (`/api/nemesis`).
struct Nemesis: Codable, Equatable {
    let playerId: String
    let name: String
    var character: String? = nil
    let battles: Int
    let wins: Int
    let losses: Int

    /// "7 : 6 für dich", "4 : 4 – Gleichstand", "2 : 5 für Mia"
    var recordText: String {
        let score = "\(wins) : \(losses)"
        if wins == losses { return "\(score) – Gleichstand" }
        return wins > losses ? "\(score) für dich" : "\(score) für \(name)"
    }
}

final class NemesisService {
    /// nil = noch kein Erzfeind (204) oder altes Backend
    func load() async throws -> Nemesis? {
        let (data, response) = try await API.data(from: BackendConfig.apiURL("api/nemesis"))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try JSONDecoder().decode(Nemesis.self, from: data)
    }
}

/// Flammen-Abzeichen am Kartenpin des Erzfeinds.
struct NemesisBadge: View {
    static let color = Color(red: 1.0, green: 0.45, blue: 0.1)

    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(.white)
            .padding(5)
            .background(Circle().fill(NemesisBadge.color))
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .shadow(color: NemesisBadge.color.opacity(0.8), radius: 5)
            .accessibilityLabel("Erzfeind")
    }
}
