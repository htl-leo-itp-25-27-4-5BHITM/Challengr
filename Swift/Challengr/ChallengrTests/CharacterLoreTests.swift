import XCTest
@testable import Challengr

/// Rahmengeschichte, Steckbriefe, Rivalen und Sieger-Sprüche.
final class CharacterLoreTests: XCTestCase {

    func testEveryCharacterHasAChapter() {
        for c in GameCharacter.allCases {
            XCTAssertFalse(c.chapterTitle.isEmpty, c.rawValue)
            XCTAssertGreaterThan(c.story.count, 80, c.rawValue)
            XCTAssertFalse(c.motto.isEmpty, c.rawValue)
            XCTAssertGreaterThanOrEqual(c.victoryLines.count, 2, c.rawValue)
        }
        XCTAssertEqual(Set(GameCharacter.allCases.map(\.chapterTitle)).count, GameCharacter.allCases.count)
        XCTAssertFalse(ChallengrStory.intro.isEmpty)
    }

    func testRivalsArePairs() {
        for c in GameCharacter.allCases {
            guard let rival = c.rival else { continue }
            XCTAssertNotEqual(rival, c)
            XCTAssertEqual(rival.rival, c, "\(c.rawValue) ↔ \(rival.rawValue)")
        }
        XCTAssertTrue(GameCharacter.sirBrecht.isRival(of: .ragnar))
        XCTAssertFalse(GameCharacter.crashDummy.isRival(of: nil))
    }

    private func result(winner: GameCharacter, loser: GameCharacter, trashTalk: String = "GG!", battleId: Int64 = 5) -> BattleResultData {
        var r = BattleResultData(winnerName: "A", winnerAvatar: "", winnerPointsDelta: 20,
                                 loserName: "B", loserAvatar: "", loserPointsDelta: -15,
                                 trashTalk: trashTalk, metrics: nil)
        r.battleId = battleId
        r.winnerId = "b"
        r.loserId = "a"
        r.participants = BattleParticipants(fromId: "a", toId: "b", fromName: "B", toName: "A",
                                            fromCharacter: loser, toCharacter: winner)
        return r
    }

    func testWinnerCharacterSpeaksAfterADefeat() {
        let r = result(winner: .ragnar, loser: .sirBrecht)
        XCTAssertEqual(r.winnerCharacter, .ragnar)
        XCTAssertEqual(r.loserCharacter, .sirBrecht)
        XCTAssertTrue(r.isRivalDuel)
        let quote = r.victoryQuote
        XCTAssertEqual(quote?.speaker, .ragnar)
        XCTAssertTrue(GameCharacter.ragnar.victoryLines.contains(quote?.text ?? ""))
        XCTAssertEqual(r.victoryQuote?.text, quote?.text, "für dasselbe Battle immer derselbe Spruch")
    }

    func testSpecialServerTextsStay() {
        XCTAssertNil(result(winner: .kai, loser: .junge, trashTalk: "Gut trainiert!").victoryQuote)
        XCTAssertFalse(result(winner: .kai, loser: .junge).isRivalDuel)
    }
}
