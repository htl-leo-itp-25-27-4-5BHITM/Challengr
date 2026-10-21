import XCTest
import CoreLocation
@testable import Challengr

final class ToonMapTests: XCTestCase {

    func testZoomMatchesTheAppleMapDistance() {
        XCTAssertEqual(ToonCamera.zoom(distance: 700), 16.4, accuracy: 0.001)
        XCTAssertEqual(ToonCamera.zoom(distance: 1400), 15.4, accuracy: 0.001, "doppelter Abstand = eine Stufe weniger")
        // Zoom-Grenzen der Karte (200 m – 2,5 km) liegen im erlaubten Bereich von MapLibre (12–19)
        XCTAssertLessThan(ToonCamera.zoom(distance: 200), 19)
        XCTAssertGreaterThan(ToonCamera.zoom(distance: 2500), 12)
    }

    func testCirclePolygonHasTheRightRadius() {
        let center = CLLocationCoordinate2D(latitude: 48.26832, longitude: 14.25138)
        let poly = ToonCamera.polygon(center: center, radius: 200)
        XCTAssertEqual(poly.first?.latitude, poly.last?.latitude, "geschlossen")
        let c = CLLocation(latitude: center.latitude, longitude: center.longitude)
        for p in poly {
            XCTAssertEqual(CLLocation(latitude: p.latitude, longitude: p.longitude).distance(from: c), 200, accuracy: 3)
        }
    }

    func testOverlappingLabelsHideTheLessImportantOne() {
        let hidden = ToonLabels.hidden([
            (id: "hotspot", point: CGPoint(x: 200, y: 400), priority: 0),
            (id: "me", point: CGPoint(x: 205, y: 402), priority: 2),
            (id: "far", point: CGPoint(x: 50, y: 100), priority: 1)
        ])
        XCTAssertEqual(hidden, ["hotspot"])
    }

    func testCartoonMapIsOnByDefaultAndStyleIsBundled() throws {
        XCTAssertTrue(ToonMapSettings.defaultOn)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "ToonMapStyle", withExtension: "json"))
        let style = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let layers = try XCTUnwrap(style?["layers"] as? [[String: Any]])
        XCTAssertTrue(layers.contains { $0["id"] as? String == "bld" }, "Gebäude-Ebene – Kreise werden darunter eingefügt")
    }
}
