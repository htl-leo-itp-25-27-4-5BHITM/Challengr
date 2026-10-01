import XCTest
import CoreLocation
@testable import Challengr

/// Lebendige Karte: Wellen, Wippen, neue Spieler.
final class MapVibeTests: XCTestCase {

    func testRipplePhaseStaysBetweenZeroAndOne() {
        for t in stride(from: -5.0, through: 5.0, by: 0.37) {
            let p = MapVibe.ripplePhase(time: t, offset: 0.5)
            XCTAssertGreaterThanOrEqual(p, 0)
            XCTAssertLessThan(p, 1)
        }
        XCTAssertEqual(MapVibe.ripplePhase(time: 1, period: 2), 0.5, accuracy: 0.0001)
    }

    func testBobIsSmallAndDiffersPerPlayer() {
        let a = MapVibe.bobOffset(time: 10, seed: "spieler-a")
        let b = MapVibe.bobOffset(time: 10, seed: "spieler-b")
        XCTAssertLessThanOrEqual(abs(a), 3)
        XCTAssertNotEqual(a, b, "Spieler wippen nicht im Gleichtakt")
        XCTAssertEqual(MapVibe.stableHash("x"), MapVibe.stableHash("x"))
    }

    func testFirstLoadAnnouncesNobody() {
        XCTAssertEqual(MapVibe.newArrivals(previous: nil, current: ["a", "b"]), [])
    }

    func testOnlyNewPlayersAreAnnounced() {
        XCTAssertEqual(MapVibe.newArrivals(previous: ["a", "b"], current: ["b", "c", "a", "d"]), ["c", "d"])
        XCTAssertEqual(MapVibe.newArrivals(previous: ["a", "b"], current: ["a"]), [])
    }

    func testAnnotationIdIsStablePerPlayer() {
        let c = CLLocationCoordinate2D(latitude: 1, longitude: 2)
        let a = PlayerAnnotation(playerId: "p1", coordinate: c, title: "A", rankName: "R")
        let b = PlayerAnnotation(playerId: "p1", coordinate: c, title: "A", rankName: "R")
        XCTAssertEqual(a.id, b.id, "Pins dürfen beim Aktualisieren nicht neu entstehen")
    }

    func testSpriteFramesLoopAndDifferPerPlayer() {
        let n = GameCharacter.mapSheetFrames
        for t in stride(from: 0.0, through: 3.0, by: 0.05) {
            let f = MapVibe.spriteFrame(time: t, seed: "a")
            XCTAssertTrue((0..<n).contains(f))
        }
        XCTAssertEqual(MapVibe.spriteFrame(time: 0, seed: "a"), MapVibe.spriteFrame(time: Double(n) / 12, seed: "a"), "Animation läuft im Kreis")
    }

    func testMapSheetsHaveAllFrames() {
        for character in GameCharacter.allCases {
            XCTAssertEqual(MapSprites.frames(of: character).count, GameCharacter.mapSheetFrames, character.mapSheetName)
        }
    }

    func testOnlyTestAppsAreShownOnTheMap() {
        XCTAssertTrue(MapPlayerFilter.isVisible(name: "test"))
        XCTAssertTrue(MapPlayerFilter.isVisible(name: " CookieClicker "))
        XCTAssertFalse(MapPlayerFilter.isVisible(name: "Gegner10"))

        let saved = MapPlayerFilter.allowedNames
        defer { MapPlayerFilter.allowedNames = saved }
        MapPlayerFilter.allowedNames = []
        XCTAssertTrue(MapPlayerFilter.isVisible(name: "Gegner10"), "leere Liste = alle zeigen")
    }

    func testMapIsTilted() {
        XCTAssertGreaterThanOrEqual(MapView.mapPitch, 45)
        XCTAssertLessThanOrEqual(MapView.mapPitch, 70)
    }
}
