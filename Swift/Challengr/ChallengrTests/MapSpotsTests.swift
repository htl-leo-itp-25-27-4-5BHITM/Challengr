import XCTest
import CoreLocation
@testable import Challengr

/// Gedränge auf der Karte: auffächern bzw. Figur mit Zahl.
final class MapSpotsTests: XCTestCase {
    private let school = CLLocationCoordinate2D(latitude: 48.26832, longitude: 14.25138)

    private func players(_ n: Int, at c: CLLocationCoordinate2D, prefix: String = "p") -> [(id: String, coordinate: CLLocationCoordinate2D)] {
        (0..<n).map { (id: "\(prefix)\($0)", coordinate: c) }
    }

    private func far(_ meters: Double) -> CLLocationCoordinate2D {
        MapSpots.offset(school, meters: meters, angle: .pi / 2)
    }

    func testLonePlayerStaysWhereHeIs() {
        let layout = MapSpots.layout(players: players(1, at: far(300)), own: school, cameraDistance: 1000)
        XCTAssertTrue(layout.positions.isEmpty)
        XCTAssertTrue(layout.crowds.isEmpty)
    }

    func testTwoOnTheSameSpotAreFannedOut() {
        let layout = MapSpots.layout(players: players(2, at: far(300)), own: school, cameraDistance: 1000)
        guard let a = layout.positions["p0"], let b = layout.positions["p1"] else { return XCTFail("beide aufgefächert") }
        let radius = MapSpots.fanRadiusPoints * MapSpots.metersPerPointPerDistance * 1000
        XCTAssertEqual(MapSpots.distance(a, b), 2 * radius, accuracy: 1, "gegenüber auf dem Kreis")
        XCTAssertEqual(MapSpots.distance(a, far(300)), radius, accuracy: 1)
    }

    func testPlayerBehindMeIsMovedNextToMe() {
        let layout = MapSpots.layout(players: players(1, at: far(10)), own: school, cameraDistance: 1000)
        guard let p = layout.positions["p0"] else { return XCTFail("steht nicht mehr hinter mir") }
        XCTAssertEqual(MapSpots.distance(p, school), MapSpots.fanRadiusPoints * MapSpots.metersPerPointPerDistance * 1000, accuracy: 1)
    }

    func testSpacingStaysTheSameOnScreenWhenZooming() {
        let near = MapSpots.layout(players: players(2, at: far(300)), own: nil, cameraDistance: 250)
        let wide = MapSpots.layout(players: players(2, at: far(300)), own: nil, cameraDistance: 2500)
        let dNear = MapSpots.distance(near.positions["p0"]!, near.positions["p1"]!)
        let dWide = MapSpots.distance(wide.positions["p0"]!, wide.positions["p1"]!)
        XCTAssertEqual(dWide / dNear, 10, accuracy: 0.1, "10× weiter weg → 10× mehr Meter")
    }

    func testSchoolyardBecomesOneCrowdPin() {
        let layout = MapSpots.layout(players: players(12, at: far(300)), own: school, cameraDistance: 1000)
        XCTAssertEqual(layout.crowds.count, 1)
        XCTAssertEqual(layout.crowds.first?.playerIds.count, 12)
        XCTAssertEqual(layout.hidden.count, 12, "keine einzelnen Pins mehr")
        XCTAssertTrue(layout.positions.isEmpty)
    }

    func testCrowdAroundMeStandsNextToMe() {
        let layout = MapSpots.layout(players: players(MapSpots.fanLimit + 1, at: school), own: school, cameraDistance: 1000)
        guard let crowd = layout.crowds.first else { return XCTFail("Figur mit Zahl") }
        XCTAssertGreaterThan(MapSpots.distance(crowd.coordinate, school), 30, "nicht hinter der eigenen Figur")
    }

    func testOrderIsStableWhenTheServerShuffles() {
        let list = players(3, at: far(300))
        let a = MapSpots.layout(players: list, own: nil, cameraDistance: 1000)
        let b = MapSpots.layout(players: list.reversed(), own: nil, cameraDistance: 1000)
        for id in ["p0", "p1", "p2"] {
            XCTAssertEqual(a.positions[id]!.latitude, b.positions[id]!.latitude, accuracy: 1e-12)
            XCTAssertEqual(a.positions[id]!.longitude, b.positions[id]!.longitude, accuracy: 1e-12)
        }
    }
}
