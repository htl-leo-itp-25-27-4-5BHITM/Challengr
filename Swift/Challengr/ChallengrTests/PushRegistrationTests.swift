import XCTest
@testable import Challengr

/// Push-Mitteilungen: Art aus der Mitteilung lesen (wie PushService.Kind im Backend).
final class PushRegistrationTests: XCTestCase {

    func testKindIsReadFromThePushPayload() {
        XCTAssertEqual(PushRegistration.kind(from: ["kind": "GIFT", "from": "a"]), .gift)
        XCTAssertEqual(PushRegistration.kind(from: ["kind": "CHALLENGE"]), .challenge)
        XCTAssertEqual(PushRegistration.kind(from: ["kind": "FRIEND_REQUEST"]), .friendRequest)
        XCTAssertEqual(PushRegistration.kind(from: ["kind": "FRIEND_ACCEPTED"]), .friendAccepted)
        XCTAssertNil(PushRegistration.kind(from: ["kind": "UNBEKANNT"]), "neuere Server-Arten ignorieren")
        XCTAssertNil(PushRegistration.kind(from: [:]), "lokale Mitteilungen ohne Art")
    }

    func testDebugBuildsUseApplesTestServer() {
        XCTAssertTrue(PushRegistration.sandbox, "Tests laufen als Debug-Build")
    }
}
