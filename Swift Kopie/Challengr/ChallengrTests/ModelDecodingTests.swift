import XCTest
@testable import Challengr

/// JSON vom Backend → Swift-Modelle.
final class ModelDecodingTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    func testChallengeWithoutChoices() throws {
        let ch = try decode(ChallengeDTO.self, #"{"id":1,"text":"10 Liegestütze","category":"Fitness","choices":null,"correctIndex":null}"#)
        XCTAssertEqual(ch.id, 1)
        XCTAssertEqual(ch.category, "Fitness")
        XCTAssertNil(ch.choices)
    }

    func testKnowledgeChallengeWithoutAnswer() throws {
        let ch = try decode(ChallengeDTO.self, #"{"id":2,"text":"?","category":"Wissen","choices":["a","b","c","d"]}"#)
        XCTAssertEqual(ch.choices?.count, 4)
        XCTAssertNil(ch.correctIndex)
    }

    func testChallengeList() throws {
        let list = try decode([ChallengeDTO].self, """
        [{"id":1,"text":"a","category":"Fitness"},{"id":2,"text":"b","category":"Mutprobe"}]
        """)
        XCTAssertEqual(list.map(\.id), [1, 2])
    }

    func testPlayer() throws {
        let p = try decode(PlayerDTO.self, #"{"id":"kc-1","name":"Max","latitude":48.2,"longitude":14.3,"points":230,"rankName":"Silber"}"#)
        XCTAssertEqual(p.id, "kc-1")
        XCTAssertEqual(p.points, 230)
        XCTAssertEqual(p.rankName, "Silber")
    }

    func testBattleHistory() throws {
        let h = try decode(BattleHistoryDTO.self, """
        {"id":3,"createdAt":"2026-09-28T10:00:00","challengeText":"x","category":"Fitness",
         "opponentName":"Moritz","winnerName":null,"status":"DONE","pointsDelta":-20,"won":false}
        """)
        XCTAssertNil(h.winnerName)
        XCTAssertFalse(h.won)
        XCTAssertEqual(h.pointsDelta, -20)
    }

    func testProfileAndLoudness() throws {
        let profile = try decode(PlayerProfileDTO.self, #"{"status":null,"badges":["first-win"]}"#)
        XCTAssertEqual(profile.badges, ["first-win"])
        let loud = try decode(PlayerLoudnessBestDTO.self, #"{"bestLoudness":null}"#)
        XCTAssertNil(loud.bestLoudness)
    }
}
