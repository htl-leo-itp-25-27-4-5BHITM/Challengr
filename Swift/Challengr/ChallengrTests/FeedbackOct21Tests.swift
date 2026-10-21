import XCTest
import SwiftUI
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
        try save(LoadingScreen().frame(width: 393, height: 852), "loading.png")
    }
}
