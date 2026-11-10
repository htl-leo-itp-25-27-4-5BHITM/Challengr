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

    func testWeakSpotsQuestionsAndDamageNumbers() throws {
        let model = BossFightModel(boss: try boss())
        let now = Date()
        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-state", "bossId": 7, "hp": 6000, "maxHp": 6000, "phase": "FIGHT",
                                                     "fighters": 2, "minFighters": 2])))
        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-weakspot", "bossId": 7, "spotId": 3, "x": 0.4, "y": 0.6, "ms": 2000])), now: now)
        XCTAssertEqual(model.weakSpot, .init(id: 3, x: 0.4, y: 0.6, deadline: now.addingTimeInterval(2)))

        // kritischer Treffer: eine große Zahl, die gleiche Änderung im Stand danach nicht nochmal
        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-crit", "bossId": 7, "spotId": 3, "damage": 120])))
        XCTAssertNil(model.weakSpot)
        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-state", "bossId": 7, "hp": 5880, "maxHp": 6000, "phase": "FIGHT",
                                                     "fighters": 2, "minFighters": 2])))
        XCTAssertEqual(model.pops.map(\.text), ["KRITISCH -120"])

        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-question", "bossId": 7, "questionId": 42, "text": "Hauptstadt?",
                                                     "options": ["A", "B", "C", "D"], "ms": 8000])), now: now)
        model.pick(2)
        XCTAssertEqual(model.question?.picked, 2)
        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-answer-result", "bossId": 7, "questionId": 42,
                                                     "correct": false, "correctIndex": 1, "damage": -100])))
        XCTAssertEqual(model.question?.correctIndex, 1)
        XCTAssertEqual(model.pops.last?.text, "FALSCH +100")
        XCTAssertEqual(model.pops.last?.heal, true)

        // Heilung durch die falsche Antwort wird nicht doppelt gezeigt, normale Treffer: kleine Zahl
        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-state", "bossId": 7, "hp": 5980, "maxHp": 6000, "phase": "FIGHT",
                                                     "fighters": 2, "minFighters": 2])))
        model.apply(try XCTUnwrap(BossMessage(json: ["type": "boss-state", "bossId": 7, "hp": 5965, "maxHp": 6000, "phase": "FIGHT",
                                                     "fighters": 2, "minFighters": 2])))
        XCTAssertEqual(model.pops.map(\.text), ["KRITISCH -120", "FALSCH +100", "-15"])
    }

    func testBossModelIsBundled() {
        XCTAssertNotNil(Bundle.main.url(forResource: "RissWaechter", withExtension: "scn"))
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
