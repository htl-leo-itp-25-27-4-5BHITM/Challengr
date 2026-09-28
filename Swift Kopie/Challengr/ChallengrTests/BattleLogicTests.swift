import XCTest
@testable import Challengr

final class BattleLogicTests: XCTestCase {

    private func result(winnerId: String?, loserId: String?, battleId: Int64? = 1,
                        winnerName: String = "Max", loserName: String = "Moritz") -> BattleResultData {
        var data = BattleResultData(
            winnerName: winnerName,
            winnerAvatar: "a",
            winnerPointsDelta: 30,
            loserName: loserName,
            loserAvatar: "b",
            loserPointsDelta: -20,
            trashTalk: "GG!",
            metrics: nil
        )
        data.battleId = battleId
        data.winnerId = winnerId
        data.loserId = loserId
        return data
    }

    // MARK: - Gehört das Ergebnis zu mir?

    func testResultForMyBattleIsRelevant() {
        XCTAssertTrue(result(winnerId: "me", loserId: "other").isRelevant(ownPlayerId: "me", currentBattleId: 1))
        XCTAssertTrue(result(winnerId: "other", loserId: "me").isRelevant(ownPlayerId: "me", currentBattleId: 1))
    }

    func testResultOfForeignBattleIsIgnored() {
        // Der Bug vom dritten Spieler
        XCTAssertFalse(result(winnerId: "a", loserId: "b").isRelevant(ownPlayerId: "me", currentBattleId: nil))
        XCTAssertFalse(result(winnerId: "a", loserId: "b").isRelevant(ownPlayerId: "me", currentBattleId: 1),
                       "Auch wenn die Battle-ID zufällig passt")
    }

    func testDrawUsesBattleId() {
        let draw = result(winnerId: nil, loserId: nil, battleId: 7)
        XCTAssertTrue(draw.isRelevant(ownPlayerId: "me", currentBattleId: 7))
        XCTAssertFalse(draw.isRelevant(ownPlayerId: "me", currentBattleId: 8))
    }

    func testOldBackendWithoutIdsIsAccepted() {
        let old = result(winnerId: nil, loserId: nil, battleId: nil)
        XCTAssertTrue(old.isRelevant(ownPlayerId: "me", currentBattleId: 3))
    }

    // MARK: - Gewonnen?

    func testWinDecidedById() {
        XCTAssertTrue(result(winnerId: "me", loserId: "x").didWin(ownPlayerId: "me", ownPlayerName: "Max"))
        XCTAssertFalse(result(winnerId: "x", loserId: "me").didWin(ownPlayerId: "me", ownPlayerName: "Max"))
    }

    func testSameNamesDoNotConfuseTheResult() {
        // Beide heißen "Max" – nur die ID entscheidet
        let data = result(winnerId: "other-max", loserId: "me", winnerName: "Max", loserName: "Max")
        XCTAssertFalse(data.didWin(ownPlayerId: "me", ownPlayerName: "Max"))
    }

    func testFallbackToNameWithoutIds() {
        let data = result(winnerId: nil, loserId: nil, winnerName: "Max")
        XCTAssertTrue(data.didWin(ownPlayerId: "me", ownPlayerName: "Max"))
        XCTAssertFalse(data.didWin(ownPlayerId: "me", ownPlayerName: "Moritz"))
    }

    func testDrawIsNotAWin() {
        let draw = result(winnerId: nil, loserId: nil, winnerName: "Niemand", loserName: "Niemand")
        XCTAssertFalse(draw.didWin(ownPlayerId: "me", ownPlayerName: "Max"))
    }

    // MARK: - Abstimmung

    func testVoteSideMapsToPlayer() {
        let own = VoteSide.playerA.winner(ownId: "me", ownName: "Max", opponentId: "you", opponentName: "Moritz")
        XCTAssertEqual(own.id, "me")
        XCTAssertEqual(own.name, "Max")

        let opp = VoteSide.playerB.winner(ownId: "me", ownName: "Max", opponentId: "you", opponentName: "Moritz")
        XCTAssertEqual(opp.id, "you")
        XCTAssertEqual(opp.name, "Moritz")
    }

    func testVoteSideWorksWithSameNames() {
        let opp = VoteSide.playerB.winner(ownId: "me", ownName: "Max", opponentId: "you", opponentName: "Max")
        XCTAssertEqual(opp.id, "you", "Gleicher Name, aber richtige ID")
    }
}
