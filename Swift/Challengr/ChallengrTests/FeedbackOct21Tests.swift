import XCTest
import SwiftUI
import CoreLocation
@testable import Challengr

final class FeedbackOct21Tests: XCTestCase {

    private let ranks = [TrophyRank(name: "Scrapper", min: 200, max: 349, color: "gray"),
                         TrophyRank(name: "Contender", min: 350, max: 599, color: "green"),
                         TrophyRank(name: "Tryhard", min: 600, max: 949, color: "blue")]

    func testRedDotOnlyForANewRank() {
        let math = TrophyRoadMath(ranks: ranks)
        XCTAssertFalse(math.hasNewRank(lastSeen: nil, trophies: 700), "Trophy Road noch nie geöffnet")
        XCTAssertFalse(math.hasNewRank(lastSeen: 360, trophies: 590), "gleicher Rang, nur mehr Trophäen")
        XCTAssertTrue(math.hasNewRank(lastSeen: 340, trophies: 355))
        XCTAssertFalse(math.hasNewRank(lastSeen: 610, trophies: 500), "abgestiegen")
    }

    func testLandmarkDecodingAndReload() throws {
        let json = """
        [{"id":"htl-leonding","name":"HTL Leonding","latitude":48.26832,"longitude":14.25138,"radiusMeters":60,"points":10,"firstOfDayBonus":15,"checkedInToday":false,"checkinsToday":0,"kind":"school","category":null},
         {"id":"osm-w-1","name":"Volksgarten","latitude":48.29,"longitude":14.29,"radiusMeters":80,"points":5,"firstOfDayBonus":5,"checkedInToday":false,"checkinsToday":0,"kind":"landmark","category":"park"}]
        """
        let list = try JSONDecoder().decode([HotspotDTO].self, from: Data(json.utf8))
        XCTAssertFalse(list[0].isLandmark)
        XCTAssertTrue(list[1].isLandmark)
        XCTAssertEqual(list[1].symbol, "tree.fill")
        XCTAssertTrue(list[1].kindText.hasPrefix("PARK"))
        // alter Server ohne kind/category
        let old = try JSONDecoder().decode(HotspotDTO.self, from: Data("""
        {"id":"x","name":"X","latitude":1,"longitude":2,"radiusMeters":60,"points":10,"firstOfDayBonus":15,"checkedInToday":false,"checkinsToday":0}
        """.utf8))
        XCTAssertFalse(old.isLandmark)

        let now = Date()
        let a = CLLocationCoordinate2D(latitude: 48.268, longitude: 14.251)
        XCTAssertFalse(HotspotSchedule.shouldReload(loadedAt: now, from: a, now: now.addingTimeInterval(30), position: a))
        XCTAssertTrue(HotspotSchedule.shouldReload(loadedAt: now, from: a, now: now.addingTimeInterval(130), position: a))
        XCTAssertTrue(HotspotSchedule.shouldReload(loadedAt: now, from: a, now: now.addingTimeInterval(30),
                                                   position: CLLocationCoordinate2D(latitude: 48.273, longitude: 14.251)))
    }

    /// Bilder für die Durchsicht (nur wenn QUEST_SNAPSHOT_DIR gesetzt ist).
    @MainActor
    func testSnapshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["QUEST_SNAPSHOT_DIR"] else { throw XCTSkip("nur auf Wunsch") }
        func save<V: View>(_ view: V, _ name: String) throws {
            let r = ImageRenderer(content: view)
            r.scale = 3
            try XCTUnwrap(r.uiImage?.pngData()).write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
        }
        try save(HStack(spacing: 20) {
            CompassView(angle: .degrees(0)) {}
            CompassView(angle: .degrees(-50)) {}
        }.padding(20).background(Color(red: 0.8, green: 0.9, blue: 0.8)), "compass.png")
        try save(HStack(alignment: .bottom, spacing: 10) {
            HotspotMarker(name: "HTL", checkedIn: false)
            HotspotMarker(name: "Park", checkedIn: false, symbol: "tree.fill")
            HotspotMarker(name: "Brunnen", checkedIn: true, symbol: "drop.fill")
        }.padding(20).background(Color(red: 0.8, green: 0.9, blue: 0.8)), "markers.png")
        try save(LoadingScreen().frame(width: 393, height: 852), "loading.png")
    }
}
