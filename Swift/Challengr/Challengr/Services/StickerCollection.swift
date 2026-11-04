import Foundation
import Combine

/// Eigene Sticker-Sammlung (der Server zählt mit): wie oft man jeden Sticker noch schicken kann
/// und welche man schon einmal bekommen hat (Album). Sticker kommen aus Geschenken, jeder Versand verbraucht einen.
final class StickerCollection: ObservableObject {
    static let shared = StickerCollection()

    /// So kommt die Sammlung vom Server (GET /api/stickers)
    struct Entry: Decodable {
        let stickerId: String
        let count: Int
        let total: Int
    }

    @Published private(set) var counts: [String: Int] = [:]
    @Published private(set) var totals: [String: Int] = [:]

    func count(of id: String) -> Int { counts[id] ?? 0 }
    func hasFound(_ id: String) -> Bool { (totals[id] ?? 0) > 0 }
    var foundCount: Int { Stickers.all.filter { hasFound($0.id) }.count }
    /// Die man gerade schicken kann, in Album-Reihenfolge
    var owned: [Sticker] { Stickers.all.filter { count(of: $0.id) > 0 } }

    func apply(_ entries: [Entry]) {
        counts = Dictionary(entries.map { ($0.stickerId, $0.count) }, uniquingKeysWith: { _, last in last })
        totals = Dictionary(entries.map { ($0.stickerId, $0.total) }, uniquingKeysWith: { _, last in last })
    }

    /// Gleich beim Schicken runterzählen; der Server meldet danach den echten Stand (sticker-stock)
    func used(_ id: String) {
        counts[id] = max(0, count(of: id) - 1)
    }

    func setCount(_ count: Int, of id: String) {
        counts[id] = count
    }

    /// Aus einem geöffneten Geschenk
    func received(_ id: String) {
        counts[id] = count(of: id) + 1
        totals[id] = (totals[id] ?? 0) + 1
    }

    func load() async {
        guard let (data, _) = try? await API.data(from: BackendConfig.apiURL("api/stickers")),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        apply(entries)
    }
}
