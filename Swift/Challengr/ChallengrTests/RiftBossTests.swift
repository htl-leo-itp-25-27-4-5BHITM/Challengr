import XCTest
import UIKit
@testable import Challengr

/// Riss-Wächter: Nachrichten vom Server und der Ablauf eines Kampfs in der App.
@MainActor
final class RiftBossTests: XCTestCase {

    private func boss(id: Int64 = 7) throws -> BossView {
        let json = #"{"id":7,"name":"Riss-Wächter","place":"Hauptplatz","latitude":48.2,"longitude":14.3,"hp":5000,"maxHp":5000,"phase":"WAITING","fighters":1,"minFighters":2,"expiresAt":"2026-11-08T16:30:00Z","fightEndsAt":null}"#
        return try JSONDecoder().decode(BossView.self, from: Data(json.utf8))
    }

    func testNearbyDecodesAndAssetsExist() throws {
        let b = try boss()
        XCTAssertEqual(b.place, "Hauptplatz")
        XCTAssertEqual(b.hpFraction, 1)
        XCTAssertNotNil(b.expiresDate)
        XCTAssertNotNil(UIImage(named: RiftBoss.imageName))
        XCTAssertNotNil(MapSprites.frame(sheet: RiftBoss.mapSheetName, at: 3))
    }

    func testFightFlowFromServerMessages() throws {
        let model = BossFightModel(boss: try boss())
        XCTAssertEqual(model.stage, .waiting)

        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-state", "bossId": 7, "hp": 5000, "maxHp": 5000, "phase": "FIGHT",
                                                     "fighters": 2, "minFighters": 2, "fightEndsAt": "2026-11-08T16:03:00Z"])))
        XCTAssertEqual(model.stage, .fight)
        XCTAssertNotNil(model.fightEndsAt)

        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-state", "bossId": 7, "hp": 4985, "maxHp": 5000, "phase": "FIGHT",
                                                     "fighters": 2, "minFighters": 2])))
        XCTAssertEqual(model.hitFlash, 1, "Treffer lässt den Boss wackeln")

        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-phase", "bossId": 7, "phase": "RAGE"])))
        XCTAssertEqual(model.stage, .rage)
        let now = Date()
        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-slam", "bossId": 7, "ms": 1500])), now: now)
        XCTAssertEqual(model.slamDeadline, now.addingTimeInterval(1.5))

        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-finale", "bossId": 7, "seconds": 6])), now: now)
        XCTAssertEqual(model.stage, .finale)
        XCTAssertNil(model.slamDeadline)

        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-phase", "bossId": 7, "phase": "RAGE", "roar": true])))
        XCTAssertEqual(model.stage, .rage)
        XCTAssertTrue(model.roared, "nicht gemeinsam laut genug – er brüllt zurück")

        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-end", "bossId": 7, "result": "DEFEATED", "shards": 14, "coins": 50])))
        XCTAssertEqual(model.stage, .won(shards: 14, coins: 50))
    }

    func testOtherBossesAndRejection() throws {
        let model = BossFightModel(boss: try boss())
        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-end", "bossId": 99, "result": "DEFEATED"])))
        XCTAssertEqual(model.stage, .waiting, "Nachrichten anderer Bosse zählen nicht")
        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-rejected", "bossId": 7, "reason": "Du bist zu weit weg"])))
        XCTAssertEqual(model.stage, .rejected("Du bist zu weit weg"))
        XCTAssertNil(BossMessage(json: ["type": "boss-unknown", "bossId": 7]))
    }
}
