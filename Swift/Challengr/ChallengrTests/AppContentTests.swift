import XCTest
@testable import Challengr

final class AppContentTests: XCTestCase {
    func testAnnouncementIsShownOnlyOnce() throws {
        let d = UserDefaults(suiteName: "ann-\(UUID())")!
        let a = try JSONDecoder().decode(AppAnnouncement.self, from: Data(#"{"id":7,"text":"Halloween!","active":true}"#.utf8))
        XCTAssertTrue(AnnouncementMemory.isNew(a, defaults: d))
        AnnouncementMemory.markSeen(a, defaults: d)
        XCTAssertFalse(AnnouncementMemory.isNew(a, defaults: d))
        XCTAssertTrue(AnnouncementMemory.isNew(AppAnnouncement(id: 8, text: "Neu"), defaults: d))
    }

    func testReportReasonsMatchTheServer() {
        XCTAssertEqual(QuizReportReason.allCases.map(\.rawValue), ["FALSCHE_ANTWORT", "UNKLAR", "TIPPFEHLER", "SONSTIGES"])
    }
}
