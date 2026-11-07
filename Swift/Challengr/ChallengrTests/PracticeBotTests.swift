import XCTest
@testable import Challengr

/// Übungsmodus gegen den Trainings-Dummy: gleiche Spielarten wie die Liga, aber ohne Trophäen.
final class PracticeBotTests: XCTestCase {

    private func result(from: String, to: String, mode: BattleMode) -> BattleResultData {
        var r = BattleResultData(winnerName: "A", winnerAvatar: "", winnerPointsDelta: 0,
                                 loserName: "B", loserAvatar: "", loserPointsDelta: 0,
                                 trashTalk: "", metrics: nil)
        r.mode = mode
        r.participants = BattleParticipants(fromId: from, toId: to)
        return r
    }

    func testBotIdMatchesTheServer() {
        XCTAssertEqual(PracticeBot.id, "practice-bot")
        XCTAssertTrue(PracticeBot.isBot("practice-bot"))
        XCTAssertFalse(PracticeBot.isBot("demo-1"))
        XCTAssertFalse(PracticeBot.isBot(nil))
        XCTAssertEqual(GameCharacter.from(serverId: "crash-dummy"), PracticeBot.character)
    }

    func testPracticeResultDoesNotCountForTheLeague() {
        let practice = result(from: "me", to: PracticeBot.id, mode: .rankedKnowledge)
        XCTAssertTrue(practice.isPractice)
        XCTAssertFalse(practice.countsForLeague)
        XCTAssertEqual(practice.deltaLabel(0), "ÜBUNG")

        let league = result(from: "me", to: "other", mode: .rankedRealLife)
        XCTAssertFalse(league.isPractice)
        XCTAssertTrue(league.countsForLeague)
        XCTAssertEqual(league.deltaLabel(28), "+28 🏆")
    }
}
