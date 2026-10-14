import XCTest
@testable import Challengr

/// Trophäenverlauf im Profil: rückwärts vom aktuellen Stand, Friendly zählt nicht.
final class TrophyHistoryTests: XCTestCase {

    private func battle(_ date: String, _ delta: Int, mode: String = "RANKED_KNOWLEDGE") -> BattleHistoryDTO {
        BattleHistoryDTO(id: 1, createdAt: "\(date)T10:00:00", challengeText: "", category: "", opponentName: "x",
                         winnerName: nil, status: "DONE", pointsDelta: delta, won: delta > 0, mode: mode)
    }

    func testEndsAtTheCurrentStandAndStartsBeforeTheFirstBattle() {
        let history = TrophyHistory.daily(battles: [
            battle("2026-10-13", 30), battle("2026-10-13", -20),
            battle("2026-10-14", 32), battle("2026-10-14", 0, mode: "FRIENDLY"),
        ], current: 242)

        XCTAssertEqual(history.map(\.date), ["Start", "2026-10-13", "2026-10-14"])
        XCTAssertEqual(history.map(\.trophies), [200, 210, 242])
    }

    func testNoLeagueBattlesNoChart() {
        XCTAssertTrue(TrophyHistory.daily(battles: [battle("2026-10-14", 0, mode: "FRIENDLY")], current: 200).isEmpty)
    }
}
