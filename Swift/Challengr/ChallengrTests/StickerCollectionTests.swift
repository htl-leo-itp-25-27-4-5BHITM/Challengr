import XCTest
@testable import Challengr

/// Sticker sammeln: Sammlung vom Server, Verbrauch beim Schicken, Geschenke, Album-Stufen, Sieg-Sticker.
final class StickerCollectionTests: XCTestCase {

    override func tearDown() {
        StickerCollection.shared.apply([])
        StickerCollection.shared.apply(StickerCollection.Album(found: 0, coins: 0, packPrice: 100, stages: []))
        StickerCollection.shared.setPendingGifts(0)
        super.tearDown()
    }

    private let albumJSON = #"""
    {"found":5,"coins":340,"packPrice":100,"stages":[
     {"found":5,"coins":50,"goldFrame":false,"claimed":false},
     {"found":10,"coins":100,"goldFrame":false,"claimed":false},
     {"found":15,"coins":150,"goldFrame":false,"claimed":false},
     {"found":20,"coins":0,"goldFrame":true,"claimed":false}]}
    """#

    func testCollectionCountsAndAlbum() throws {
        let json = #"[{"stickerId":"oida","count":2,"total":3},{"stickerId":"aura","count":0,"total":1}]"#
        let entries = try JSONDecoder().decode([StickerCollection.Entry].self, from: Data(json.utf8))
        let c = StickerCollection.shared
        c.apply(entries)
        XCTAssertEqual(c.count(of: "oida"), 2)
        XCTAssertEqual(c.owned.map(\.id), ["oida"], "alle verschickt → nicht mehr auswählbar")
        XCTAssertTrue(c.hasFound("aura"), "bleibt im Album")
        XCTAssertFalse(c.hasFound("mvp"))
        XCTAssertEqual(c.foundCount, 2)

        c.used("oida"); c.used("oida"); c.used("oida")
        XCTAssertEqual(c.count(of: "oida"), 0, "nie unter 0")
        c.received("mvp")
        XCTAssertEqual(c.count(of: "mvp"), 1)
        XCTAssertEqual(c.foundCount, 3)
        c.setCount(5, of: "aura")
        XCTAssertEqual(c.owned.map(\.id), ["aura", "mvp"], "Reihenfolge wie im Album")
    }

    func testStockAndGiftMessagesAreParsed() async {
        let socket = GameSocketService(playerId: "me")
        let stock = expectation(description: "stock")
        let gift = expectation(description: "gift")
        socket.onStickerStock = { id, count in
            XCTAssertEqual(id, "oida"); XCTAssertEqual(count, 4); stock.fulfill()
        }
        socket.onGiftReceived = { from in
            XCTAssertEqual(from, "mia"); gift.fulfill()
        }
        socket.handleIncoming(text: #"{"type":"sticker-stock","sticker":"oida","count":4}"#)
        socket.handleIncoming(text: #"{"type":"gift-received","fromPlayerId":"mia"}"#)
        await fulfillment(of: [stock, gift], timeout: 2)
    }

    func testGiftDecodesTheStickerInside() throws {
        let opened = #"{"id":5,"fromPlayerId":"a","toPlayerId":"b","status":"CLAIMED","createdAt":"2026-11-04T10:00:00Z","claimedAt":"2026-11-04T10:01:00Z","stickerId":"1hit"}"#
        XCTAssertEqual(try JSONDecoder().decode(FriendGiftDTO.self, from: Data(opened.utf8)).stickerId, "1hit")
        let pending = #"{"id":6,"fromPlayerId":"a","toPlayerId":"b","status":"PENDING","createdAt":"2026-11-04T10:00:00Z","claimedAt":null}"#
        XCTAssertNil(try JSONDecoder().decode(FriendGiftDTO.self, from: Data(pending.utf8)).stickerId, "ältere Server ohne Feld")
        XCTAssertTrue(FriendGifts.isEnabled)
    }

    func testEmptyStickersStayVisibleAndAreCounted() throws {
        let json = #"[{"stickerId":"oida","count":2,"total":3},{"stickerId":"aura","count":0,"total":1}]"#
        let c = StickerCollection.shared
        c.apply(try JSONDecoder().decode([StickerCollection.Entry].self, from: Data(json.utf8)))
        XCTAssertEqual(c.found.map(\.id), ["aura", "oida"], "leere bleiben in der Auswahl (grau)")
        XCTAssertEqual(c.sendableCount, 2)
    }

    func testAlbumStagesAndBadge() throws {
        let c = StickerCollection.shared
        c.apply(try JSONDecoder().decode(StickerCollection.Album.self, from: Data(albumJSON.utf8)))
        XCTAssertEqual(c.coins, 340)
        XCTAssertEqual(c.stages.map(\.found), [5, 10, 15, 20])
        XCTAssertTrue(c.claimableStages.isEmpty, "noch nichts gefunden")

        Stickers.all.prefix(5).forEach { c.received($0.id) }
        XCTAssertEqual(c.claimableStages.map(\.found), [5])
        c.setPendingGifts(2)
        XCTAssertEqual(c.badge, 3, "2 Geschenke + 1 Stufe")
        XCTAssertFalse(c.hasGoldFrame)

        let full = albumJSON.replacingOccurrences(of: #""goldFrame":true,"claimed":false"#, with: #""goldFrame":true,"claimed":true"#)
        c.apply(try JSONDecoder().decode(StickerCollection.Album.self, from: Data(full.utf8)))
        XCTAssertTrue(c.hasGoldFrame)
    }

    func testStagesMatchTheBackend() throws {
        // wie StickerCatalog.STAGES: die letzte Stufe ist das volle Album
        let album = try JSONDecoder().decode(StickerCollection.Album.self, from: Data(albumJSON.utf8))
        XCTAssertEqual(album.stages.last?.found, Stickers.all.count)
        XCTAssertEqual(StickerCollection.packSize, 3)
    }

    func testChosenGiftAndDailyStickerDecode() throws {
        let gift = #"{"id":7,"fromPlayerId":"a","toPlayerId":"b","status":"CLAIMED","createdAt":"x","claimedAt":"y","stickerId":"aura","fromCollection":true}"#
        XCTAssertEqual(try JSONDecoder().decode(FriendGiftDTO.self, from: Data(gift.utf8)).fromCollection, true)

        let board = #"""
        {"coins":60,"day":"2026-11-05","resetsAt":"2026-11-05T23:00:00Z","claimedSticker":"mvp","events":[],
         "daily":[{"id":"VISIT","title":"Schau vorbei","icon":"hand.wave.fill","target":1,"progress":1,"coins":10,"claimed":true,"sticker":true}]}
        """#
        let decoded = try JSONDecoder().decode(QuestBoard.self, from: Data(board.utf8))
        XCTAssertEqual(decoded.claimedSticker, "mvp")
        XCTAssertEqual(decoded.daily.first?.sticker, true)
        let old = #"{"coins":0,"day":"d","resetsAt":"r","events":[],"daily":[]}"#
        XCTAssertNil(try JSONDecoder().decode(QuestBoard.self, from: Data(old.utf8)).claimedSticker, "alte Server")
    }

    func testBattleResultCarriesTheWinnerSticker() async {
        let socket = GameSocketService(playerId: "me")
        let exp = expectation(description: "result")
        socket.onBattleResult = { result in
            XCTAssertEqual(result.winnerSticker?.id, "aura")
            exp.fulfill()
        }
        socket.handleIncoming(text: #"{"type":"battle-result","battleId":1,"outcome":"WIN","mode":"RANKED_KNOWLEDGE","winnerId":"me","winnerName":"Me","winnerPointsDelta":20,"loserId":"o","loserName":"O","loserPointsDelta":-20,"winnerSticker":"aura","trashTalk":"GG!","fromId":"me","toId":"o"}"#)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testOwnPlayerKnowsTheGoldFrame() throws {
        let json = #"{"id":"a","name":"A","latitude":null,"longitude":null,"points":0,"rankName":"Bronze","goldFrame":true}"#
        XCTAssertEqual(try JSONDecoder().decode(PlayerDTO.self, from: Data(json.utf8)).goldFrame, true)
    }
}
