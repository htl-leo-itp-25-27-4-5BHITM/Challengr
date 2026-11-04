import XCTest
@testable import Challengr

/// Sticker sammeln: Sammlung vom Server, Verbrauch beim Schicken, Geschenke mit Sticker.
final class StickerCollectionTests: XCTestCase {

    override func tearDown() {
        StickerCollection.shared.apply([])
        super.tearDown()
    }

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
}
