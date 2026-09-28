import XCTest
@testable import Challengr

final class ChallengeLookupTests: XCTestCase {

    private let pushups = ChallengeDTO(id: 1, text: "Liegestütze", category: "Fitness", choices: nil, correctIndex: nil)
    private let quiz = ChallengeDTO(id: 2, text: "Hauptstadt?", category: "Wissen", choices: ["a", "b", "c", "d"], correctIndex: nil)
    private let custom = ChallengeDTO(id: 3, text: "Tanz!", category: " customer ", choices: nil, correctIndex: nil)

    private struct Offline: Error {}

    // MARK: - ChallengeResolver

    func testPayloadFromBackendWins() async {
        var fetched = false
        let r = await ChallengeResolver.resolve(id: 1, text: "Vom Server", category: "Mutprobe", cached: [pushups]) { _ in
            fetched = true
            return self.pushups
        }
        XCTAssertEqual(r.name, "Vom Server")
        XCTAssertEqual(r.category, "Mutprobe")
        XCTAssertNil(r.fetched)
        XCTAssertFalse(fetched, "Kein Netzwerk nötig")
    }

    func testCacheIsUsedWhenPayloadMissing() async {
        let r = await ChallengeResolver.resolve(id: 2, text: nil, category: nil, cached: [pushups, quiz]) { _ in
            XCTFail("Darf nicht laden, wenn im Cache")
            return self.quiz
        }
        XCTAssertEqual(r.name, "Hauptstadt?")
        XCTAssertEqual(r.category, "Wissen")
    }

    func testEmptyPayloadCountsAsMissing() async {
        let r = await ChallengeResolver.resolve(id: 1, text: "", category: "", cached: [pushups]) { _ in self.quiz }
        XCTAssertEqual(r.name, "Liegestütze")
    }

    func testUnknownChallengeIsLoadedById() async {
        var requestedId: Int64?
        let r = await ChallengeResolver.resolve(id: 3, text: nil, category: nil, cached: [pushups]) { id in
            requestedId = id
            return self.custom
        }
        XCTAssertEqual(requestedId, 3)
        XCTAssertEqual(r.name, "Tanz!")
        XCTAssertEqual(r.fetched?.id, 3, "Geladene Challenge wird für den Cache zurückgegeben")
    }

    func testOfflineFallbackNeverGuessesAnotherChallenge() async {
        let r = await ChallengeResolver.resolve(id: 99, text: nil, category: nil, cached: [pushups, quiz]) { _ in
            throw Offline()
        }
        XCTAssertEqual(r.name, "Challenge 99")
        XCTAssertEqual(r.category, "Unbekannt")
        XCTAssertNil(r.fetched)
    }

    // MARK: - ChallengePicker

    func testFilterIgnoresCaseAndSpaces() {
        let all = [pushups, quiz, custom]
        XCTAssertEqual(ChallengePicker.challenges(in: "Customer", from: all).map(\.id), [3])
        XCTAssertEqual(ChallengePicker.challenges(in: "fitness", from: all).map(\.id), [1])
        XCTAssertTrue(ChallengePicker.challenges(in: "iPhone", from: all).isEmpty)
    }

    func testRandomPicksOnlyFromCategory() {
        let all = [pushups, quiz, custom]
        for _ in 0..<50 {
            XCTAssertEqual(ChallengePicker.random(in: "Wissen", from: all)?.id, 2)
        }
        XCTAssertNil(ChallengePicker.random(in: "Mutprobe", from: all))
    }
}
