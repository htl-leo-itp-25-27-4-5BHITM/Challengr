import XCTest
import SwiftUI
import CoreLocation
@testable import Challengr

final class NewChallengeTests: XCTestCase {

    private let leonding = CLLocationCoordinate2D(latitude: 48.26832, longitude: 14.25138)

    func testBothPlayersGetTheSameTargets() {
        // gleiche Battle-Nummer → gleiche Werte (auf jedem Gerät)
        XCTAssertEqual(ChallengeSeed.country(battleId: 4711), ChallengeSeed.country(battleId: 4711))
        XCTAssertEqual(ChallengeSeed.compassTarget(battleId: 4711), ChallengeSeed.compassTarget(battleId: 4711))
        XCTAssertEqual(ChallengeSeed.reactionDelays(battleId: 4711), ChallengeSeed.reactionDelays(battleId: 4711))
        XCTAssertEqual(ChallengeSeed.timingTarget(battleId: 4711), ChallengeSeed.timingTarget(battleId: 4711))
        // verschiedene Battles → Abwechslung
        let countries = Set((1...60).map { ChallengeSeed.country(battleId: Int64($0)).name })
        XCTAssertGreaterThan(countries.count, 15)
        for id in 1...50 {
            let delays = ChallengeSeed.reactionDelays(battleId: Int64(id))
            XCTAssertEqual(delays.count, ReactionRules.rounds)
            XCTAssertTrue(delays.allSatisfy { (1.5...4.0).contains($0) })
            XCTAssertTrue([5, 6, 7, 8, 10].contains(ChallengeSeed.timingTarget(battleId: Int64(id))))
            XCTAssertTrue((0..<360).contains(ChallengeSeed.compassTarget(battleId: Int64(id))))
        }
    }

    func testBearingsFromLeondingPointTheRightWay() {
        func bearing(_ name: String) -> Double { Country.all.first { $0.name == name }!.bearing(from: leonding) }
        XCTAssertEqual(bearing("Italien"), 195, accuracy: 15, "Rom liegt südlich")
        XCTAssertEqual(bearing("Deutschland"), 355, accuracy: 15, "Berlin liegt fast genau nördlich")
        XCTAssertEqual(bearing("Frankreich"), 270, accuracy: 20, "Paris liegt westlich")
        XCTAssertEqual(bearing("Japan"), 40, accuracy: 15, "Tokio auf dem Großkreis nordöstlich")
        XCTAssertEqual(angleBetween(350, 10), 20)
        XCTAssertEqual(angleBetween(0, 180), 180)
    }

    func testReactionAverage() {
        XCTAssertEqual(ReactionRules.average([200, 300, 1000]), 500)
        XCTAssertEqual(ReactionRules.average([]), ReactionRules.penaltyMs)
    }

    func testChallengeRoutingAndEveryMeasuredChallengeIsExplained() {
        XCTAssertEqual(BattleScreen.forChallenge(category: "iPhone", name: "Länder-Kompass: Zeig in die Richtung des Landes – wer genauer zeigt, gewinnt."), .country)
        XCTAssertEqual(BattleScreen.forChallenge(category: "iPhone", name: "Reaktions-Test: Tippe sofort, wenn der Bildschirm grün wird."), .reaction)
        XCTAssertEqual(BattleScreen.forChallenge(category: "iPhone", name: "Zeitgefühl: Stoppe genau nach der Zielzeit – ohne Uhr."), .timing)
        XCTAssertEqual(BattleScreen.forChallenge(category: "iPhone", name: "Kompass-Präzision: Richte dich auf einen zufälligen Zielwinkel aus."), .compass)
        for s: BattleScreen in [.sprint, .loudness, .compass, .shake, .pushup, .checkInSpot, .country, .reaction, .timing] {
            let intro = ChallengeIntro.for(s)
            XCTAssertNotNil(intro, "\(s) braucht eine Erklärung")
            XCTAssertGreaterThanOrEqual(intro?.steps.count ?? 0, 2)
        }
        XCTAssertNil(ChallengeIntro.for(.knowledge))
        XCTAssertEqual(ChallengeIntro.for(.pushup)?.getReadySeconds, 5, "Zeit, um sich hinzulegen")
    }

    func testMetricRowsForNewChallenges() {
        let m = BattleMetrics(sprint: nil, loudness: nil, compass: nil, shake: nil, pushup: nil,
                              country: BattleMetricPair(winner: 12, loser: 80),
                              reaction: BattleMetricPair(winner: 245, loser: 390),
                              timing: BattleMetricPair(winner: 120, loser: 1450))
        let rows = m.rows
        XCTAssertEqual(rows.map(\.title), ["LÄNDER-KOMPASS", "REAKTION", "ZEITGEFÜHL"])
        XCTAssertEqual(rows[1].winner, "245 ms")
        XCTAssertEqual(rows[2].loser, "1.45 s daneben")
    }

    /// Bilder für die Durchsicht (nur wenn QUEST_SNAPSHOT_DIR gesetzt ist).
    @MainActor
    func testSnapshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["QUEST_SNAPSHOT_DIR"] else { throw XCTSkip("nur auf Wunsch") }
        func save<V: View>(_ view: V, _ name: String) throws {
            let r = ImageRenderer(content: view.frame(width: 393, height: 852).environment(\.colorScheme, .dark))
            r.scale = 2
            try XCTUnwrap(r.uiImage?.pngData()).write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
        }
        let socket = GameSocketService(playerId: "me")
        try save(ChallengeIntroGate(intro: ChallengeIntro.for(.country)) { EmptyView() }, "intro_country.png")
        try save(ChallengeIntroGate(intro: ChallengeIntro.for(.compass)) { EmptyView() }, "intro_compass.png")
        try save(CountryCompassView(battleId: 7, socket: socket, position: leonding, onClose: {}), "country.png")
        try save(ReactionChallengeView(battleId: 7, socket: socket, onClose: {}), "reaction.png")
        try save(TimingChallengeView(battleId: 7, socket: socket, onClose: {}), "timing.png")
    }
}
