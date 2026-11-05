import Foundation
import Combine

/// Eigene Sticker-Sammlung (der Server zählt mit): wie oft man jeden Sticker noch schicken kann
/// und welche man schon einmal bekommen hat (Album). Sticker kommen aus Geschenken, Liga-Siegen,
/// der Tagesaufgabe und dem Shop-Paket; jeder Versand verbraucht einen.
final class StickerCollection: ObservableObject {
    static let shared = StickerCollection()
    /// So viele Sticker stecken in einem Paket (wie StickerCatalog.PACK_SIZE im Backend)
    static let packSize = 3

    /// So kommt die Sammlung vom Server (GET /api/stickers)
    struct Entry: Decodable {
        let stickerId: String
        let count: Int
        let total: Int
    }

    /// Album-Stufe: ab `found` gefundenen Stickern gibt's Coins, beim vollen Album den goldenen Rahmen
    struct Stage: Decodable, Equatable, Identifiable {
        let found: Int
        let coins: Int
        let goldFrame: Bool
        let claimed: Bool

        var id: Int { found }
    }

    /// GET /api/stickers/album
    struct Album: Decodable {
        let found: Int
        let coins: Int
        let packPrice: Int
        let stages: [Stage]
    }

    struct Pack: Decodable {
        let stickers: [String]
        let coins: Int
    }

    enum PackError: LocalizedError {
        case notEnoughCoins

        var errorDescription: String? { "Dafür hast du noch nicht genug Coins – Tagesaufgaben bringen welche." }
    }

    @Published private(set) var counts: [String: Int] = [:]
    @Published private(set) var totals: [String: Int] = [:]
    @Published private(set) var stages: [Stage] = []
    /// Challengr Coins (wie in den Aufgaben)
    @Published private(set) var coins: Int? = nil
    @Published private(set) var packPrice = 100
    /// Ungeöffnete Geschenke (Zahl am Menü-Knopf "Sticker")
    @Published private(set) var pendingGifts = 0

    func count(of id: String) -> Int { counts[id] ?? 0 }
    func hasFound(_ id: String) -> Bool { (totals[id] ?? 0) > 0 }
    var foundCount: Int { Stickers.all.filter { hasFound($0.id) }.count }
    /// Die man gerade schicken kann, in Album-Reihenfolge
    var owned: [Sticker] { Stickers.all.filter { count(of: $0.id) > 0 } }
    /// Alle schon gefundenen – leere bleiben sichtbar (grau), damit nichts "verschwindet"
    var found: [Sticker] { Stickers.all.filter { hasFound($0.id) } }
    /// So viele Sticker kann man insgesamt noch schicken
    var sendableCount: Int { owned.reduce(0) { $0 + count(of: $1.id) } }

    /// Stufen, die man gerade abholen kann
    var claimableStages: [Stage] { stages.filter { !$0.claimed && foundCount >= $0.found } }
    var hasGoldFrame: Bool { stages.contains { $0.goldFrame && $0.claimed } }
    /// Zahl am Menü-Knopf: ungeöffnete Geschenke + abholbare Album-Stufen
    var badge: Int { pendingGifts + claimableStages.count }

    func apply(_ entries: [Entry]) {
        counts = Dictionary(entries.map { ($0.stickerId, $0.count) }, uniquingKeysWith: { _, last in last })
        totals = Dictionary(entries.map { ($0.stickerId, $0.total) }, uniquingKeysWith: { _, last in last })
    }

    func apply(_ album: Album) {
        stages = album.stages
        coins = album.coins
        packPrice = album.packPrice
    }

    /// Gleich beim Schicken runterzählen; der Server meldet danach den echten Stand (sticker-stock)
    func used(_ id: String) {
        counts[id] = max(0, count(of: id) - 1)
    }

    func setCount(_ count: Int, of id: String) {
        counts[id] = count
    }

    /// Neu bekommen (Geschenk, Sieg, Aufgabe, Paket)
    func received(_ id: String) {
        counts[id] = count(of: id) + 1
        totals[id] = (totals[id] ?? 0) + 1
    }

    func setPendingGifts(_ count: Int) {
        pendingGifts = count
    }

    func load() async {
        if let (data, _) = try? await API.data(from: BackendConfig.apiURL("api/stickers")),
           let entries = try? JSONDecoder().decode([Entry].self, from: data) {
            apply(entries)
        }
        if let (data, _) = try? await API.data(from: BackendConfig.apiURL("api/stickers/album")),
           let album = try? JSONDecoder().decode(Album.self, from: data) {
            apply(album)
        }
    }

    func refreshGifts(playerId: String) async {
        guard let gifts = try? await FriendsService().loadIncomingGifts(playerId: playerId) else { return }
        pendingGifts = gifts.count
    }

    /// Album-Stufe abholen (Coins bzw. goldener Rahmen)
    func claimStage(_ stage: Stage) async throws {
        let album: Album = try await post("api/stickers/album/\(stage.found)/claim")
        apply(album)
    }

    /// Sticker-Paket kaufen; gibt die neuen Sticker zurück (schon in der Sammlung)
    func buyPack() async throws -> [Sticker] {
        let pack: Pack
        do {
            pack = try await post("api/stickers/pack")
        } catch let error as URLError where error.code == .resourceUnavailable {
            throw PackError.notEnoughCoins
        }
        pack.stickers.forEach(received)
        coins = pack.coins
        return pack.stickers.compactMap(Stickers.byId)
    }

    /// Freunde, denen dieser Sticker im Album noch fehlt
    func friendsMissing(_ sticker: Sticker) async -> Set<String> {
        let url = BackendConfig.apiURL("api/stickers/\(sticker.id)/friends-missing")
        guard let (data, _) = try? await API.data(from: url),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids)
    }

    /// 409 (z. B. zu wenig Coins) kommt als `.resourceUnavailable`
    private func post<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: BackendConfig.apiURL(path))
        request.httpMethod = "POST"
        let (data, response) = try await API.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(http.statusCode == 409 ? .resourceUnavailable : .badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
