import XCTest
@testable import Challengr

/// Trophy Road: Position der Figur, Rang-Grenzen und nächster Rang.
final class TrophyRoadMathTests: XCTestCase {

    /// Wie in reference-data.sql (absichtlich unsortiert – kommt so vom Server).
    private let road = TrophyRoadMath(ranks: [
        TrophyRank(name: "Scrapper", min: 200, max: 349, color: "green"),
        TrophyRank(name: "Quitter", min: 0, max: 99, color: "gray"),
        TrophyRank(name: "Punchbag", min: 100, max: 199, color: "red"),
        TrophyRank(name: "Contender", min: 350, max: 599, color: "yellow"),
        TrophyRank(name: "Challengr", min: 2000, max: 2800, color: "yellow"),
    ])

    func testRankBordersAndOpenTop() {
        XCTAssertEqual(road.rank(for: 0)?.name, "Quitter")
        XCTAssertEqual(road.rank(for: 199)?.name, "Punchbag")
        XCTAssertEqual(road.rank(for: 200)?.name, "Scrapper")
        XCTAssertEqual(road.rank(for: 5000)?.name, "Challengr", "über 2800 bleibt man im höchsten Rang")
    }

    func testFigureMovesUpWithTrophies() {
        XCTAssertEqual(road.position(for: 0), 0, accuracy: 0.001)
        XCTAssertEqual(road.position(for: 200), 2, accuracy: 0.001, "Rang-Beginn = Station")
        XCTAssertEqual(road.position(for: 275), 2.5, accuracy: 0.001, "halb zum nächsten Rang")
        XCTAssertLessThan(road.position(for: 349), road.position(for: 350))
        XCTAssertEqual(road.position(for: 9999), 4.9, accuracy: 0.001, "ganz oben, Ziel bleibt vorn")
    }

    func testProgressUsesTheNextRankNotTheOwnMax() {
        // Zwischen Contender (350) und Challengr (2000) fehlen Ränge – der Weg reicht trotzdem bis 2000
        XCTAssertEqual(road.progressInRank(1175), 0.5, accuracy: 0.001)
        XCTAssertEqual(road.trophiesToNextRank(1175), 825)
        XCTAssertEqual(road.nextRank(after: 1175)?.name, "Challengr")
        XCTAssertNil(road.nextRank(after: 2500))
    }

    func testRememberedStand() {
        let defaults = UserDefaults(suiteName: "TrophyRoadMathTests")!
        defaults.removePersistentDomain(forName: "TrophyRoadMathTests")
        XCTAssertNil(TrophyRoadMemory.lastSeen(playerId: "p", defaults: defaults))
        TrophyRoadMemory.remember(420, playerId: "p", defaults: defaults)
        XCTAssertEqual(TrophyRoadMemory.lastSeen(playerId: "p", defaults: defaults), 420)
    }
}
