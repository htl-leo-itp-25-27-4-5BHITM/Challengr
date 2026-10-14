import XCTest
import CoreLocation
@testable import Challengr

/// Tag/Nacht nach echtem Sonnenstand (Linz/Leonding, 14. Oktober 2026, Sommerzeit UTC+2).
final class SkyCycleTests: XCTestCase {
    private let leonding = CLLocationCoordinate2D(latitude: 48.268, longitude: 14.251)

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
    private func sky(_ iso: String) -> SkyState { SkyCycle.sky(at: date(iso), coordinate: leonding) }

    func testNoonIsBrightDay() {
        let s = sky("2026-10-14T11:00:00Z")   // 13:00 Ortszeit, Sonne am höchsten
        XCTAssertEqual(s.elevation, 33, accuracy: 3)
        XCTAssertFalse(s.isDark)
        XCTAssertEqual(s.twilight, 0)
        XCTAssertEqual(s.night, 0)
    }

    func testEveningTwilightThenNight() {
        let sunset = sky("2026-10-14T16:20:00Z")      // ~18:20 Ortszeit
        XCTAssertEqual(sunset.elevation, 0, accuracy: 2.5, "Sonnenuntergang um ~18:20")
        XCTAssertFalse(sunset.rising)
        XCTAssertGreaterThan(sunset.twilight, 0.6)

        let night = sky("2026-10-14T21:00:00Z")       // 23:00 Ortszeit
        XCTAssertTrue(night.isDark)
        XCTAssertEqual(night.night, 1)
        XCTAssertEqual(night.twilight, 0)
    }

    func testMorningIsRising() {
        let dawn = sky("2026-10-15T05:20:00Z")        // ~7:20 Ortszeit, Sonnenaufgang
        XCTAssertTrue(dawn.rising)
        XCTAssertGreaterThan(dawn.twilight, 0.5)
    }

    func testStarsAreStable() {
        XCTAssertEqual(StarField.star(7).x, StarField.star(7).x)
        for i in 0..<StarField.count {
            let s = StarField.star(i)
            XCTAssert((0...1).contains(s.x) && (0...1).contains(s.y))
        }
    }
}
