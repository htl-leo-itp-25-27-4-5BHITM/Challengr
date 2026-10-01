import XCTest
@testable import Challengr

/// Tests für die Fixes aus dem Audit (BUG-02, BUG-03, BUG-05, BUG-08).
final class BattleFixesTests: XCTestCase {

    // MARK: - BUG-02: Anfrage während eines Battles

    func testIncomingRequestIsShownWhenIdle() {
        XCTAssertEqual(ChallengeRouter.route(fromId: "a", toId: "me", ownPlayerId: "me", isInBattle: false), .incoming)
    }

    func testIncomingRequestIsDeclinedDuringBattle() {
        XCTAssertEqual(ChallengeRouter.route(fromId: "c", toId: "me", ownPlayerId: "me", isInBattle: true), .declineBusy)
    }

    func testOwnRequestIsOutgoingEvenDuringBattle() {
        // Nachgelieferte eigene Anfrage wird nie abgelehnt – das Backend verhindert neue Anfragen im Battle.
        XCTAssertEqual(ChallengeRouter.route(fromId: "me", toId: "b", ownPlayerId: "me", isInBattle: false), .outgoing)
    }

    func testForeignRequestIsIgnored() {
        XCTAssertEqual(ChallengeRouter.route(fromId: "a", toId: "b", ownPlayerId: "me", isInBattle: false), .ignore)
    }

    func testAcceptOfUnknownBattleDoesNotHijackRunningBattle() {
        // Battle 15 (Anfrage eines Dritten) darf das laufende Battle 14 nicht ersetzen.
        XCTAssertEqual(ChallengeRouter.acceptedRequest(battleId: 15, incomingId: nil, outgoingId: nil), .ignore)
    }

    // MARK: - BUG-05: Neustart mit offener eigener Anfrage

    func testAcceptOfRestoredOutgoingRequestStartsBattle() {
        XCTAssertEqual(ChallengeRouter.acceptedRequest(battleId: 7, incomingId: nil, outgoingId: 7), .outgoing)
    }

    func testAcceptOfIncomingRequest() {
        XCTAssertEqual(ChallengeRouter.acceptedRequest(battleId: 3, incomingId: 3, outgoingId: 9), .incoming)
    }

    // MARK: - BUG-03: Countdown im Wissens-Battle

    func testKnowledgeCountdownRoundsUpAndStopsAtZero() {
        let now = Date()
        XCTAssertEqual(KnowledgeTimer.secondsLeft(until: now.addingTimeInterval(29.2), now: now), 30)
        XCTAssertEqual(KnowledgeTimer.secondsLeft(until: now.addingTimeInterval(0.1), now: now), 1)
        XCTAssertEqual(KnowledgeTimer.secondsLeft(until: now.addingTimeInterval(-3), now: now), 0)
    }

    // MARK: - BUG-08: Battle-Layout passt auf alle iPhones

    /// Bildschirmgrößen in pt: SE, 16e, 17 Pro, 17 Pro Max.
    private let screens: [CGSize] = [
        CGSize(width: 375, height: 667), CGSize(width: 390, height: 844),
        CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)
    ]

    func testPlayerCardsFitTheScreenWidth() {
        for screen in screens {
            let stageWidth = screen.width - BattleStageLayout.horizontalInsets
            let layout = BattleStageLayout(stageWidth: stageWidth, stageHeight: min(max(screen.height - 320, 280), 560))
            XCTAssertLessThanOrEqual(layout.stripWidth, stageWidth, "Karte zu breit auf \(screen.width) pt")
            XCTAssertGreaterThanOrEqual(layout.nameMaxWidth, BattleStageLayout.nameMinWidth)
        }
    }

    func testPlayerCardsFitTheStageHeight() {
        for screen in screens {
            let height = min(max(screen.height - 320, 280), 560)
            let layout = BattleStageLayout(stageWidth: screen.width - BattleStageLayout.horizontalInsets, stageHeight: height)
            XCTAssertLessThanOrEqual(layout.stripHeight * 2 + BattleStageLayout.vsHeight, height + 0.5,
                                     "Karten überdecken den Titel auf \(screen.height) pt")
        }
    }

    func testLargeScreensKeepTheFullSizeAvatar() {
        let layout = BattleStageLayout(stageWidth: 440 - BattleStageLayout.horizontalInsets, stageHeight: 560)
        XCTAssertEqual(layout.avatarSize.width, BattleStageLayout.maxAvatarWidth, accuracy: 0.5)
        XCTAssertFalse(layout.compact)
    }

    // MARK: - BUG-03: Unentschieden wird als solches angezeigt

    private func result(outcome: String?, trashTalk: String = "Unentschieden!") -> BattleResultData {
        var r = BattleResultData(winnerName: "Niemand", winnerAvatar: "a", winnerPointsDelta: 0,
                                 loserName: "Niemand", loserAvatar: "b", loserPointsDelta: 0,
                                 trashTalk: trashTalk, metrics: nil)
        r.outcome = outcome
        return r
    }

    func testDrawIsRecognized() {
        XCTAssertTrue(result(outcome: "DRAW").isDraw)
        XCTAssertTrue(result(outcome: nil).isDraw, "Altes Backend: Erkennung über den Text")
    }

    func testConflictIsNoDraw() {
        XCTAssertFalse(result(outcome: "CONFLICT", trashTalk: "Keine Einigung – Konflikt-Penalty.").isDraw)
        XCTAssertFalse(result(outcome: nil, trashTalk: "Keine Einigung – Konflikt-Penalty.").isDraw)
    }

    func testDrawIsNotAWin() {
        XCTAssertFalse(result(outcome: "DRAW").didWin(ownPlayerId: "me", ownPlayerName: "Niemand"))
    }

    func testHistoryShowsDraws() {
        let draw = BattleHistoryDTO(id: 1, createdAt: "", challengeText: "Q", category: "Wissen", opponentName: "Lena",
                                    winnerName: nil, status: "DONE", pointsDelta: 0, won: false)
        let loss = BattleHistoryDTO(id: 2, createdAt: "", challengeText: "Q", category: "Wissen", opponentName: "Lena",
                                    winnerName: "Lena", status: "DONE", pointsDelta: -20, won: false)
        XCTAssertTrue(draw.isDraw)
        XCTAssertFalse(loss.isDraw)
    }
}
