import XCTest
import CoreLocation
@testable import Challengr

/// Karten-Menü, Hotspot und Emotes.
final class MapFeaturesTests: XCTestCase {

    func testMenuButtonsFormAnArcAboveTheCoin() {
        let n = 5
        let offsets = (0..<n).map { MapMenuLayout.offset(index: $0, count: n) }
        XCTAssertTrue(offsets.allSatisfy { $0.height < 0 }, "alle über der Münze")
        XCTAssertLessThan(offsets.first!.width, 0, "erster links")
        XCTAssertGreaterThan(offsets.last!.width, 0, "letzter rechts")
        XCTAssertEqual(offsets[2].width, 0, accuracy: 0.001, "mittlerer genau über der Münze")
        for o in offsets {
            XCTAssertEqual(hypot(o.width, o.height), MapMenuLayout.radius, accuracy: 0.001)
        }
    }

    private func hotspot(checked: Bool = false) -> HotspotDTO {
        HotspotDTO(id: "htl-leonding", name: "HTL Leonding", latitude: 48.26832, longitude: 14.25138,
                   radiusMeters: 60, points: 10, firstOfDayBonus: 15, checkedInToday: checked, checkinsToday: 0)
    }

    func testHotspotState() {
        let school = CLLocationCoordinate2D(latitude: 48.26832, longitude: 14.25138)
        XCTAssertEqual(HotspotState.of(hotspot(), playerAt: school), .inRange)
        XCTAssertEqual(HotspotState.of(hotspot(), playerAt: nil), .noLocation)
        XCTAssertEqual(HotspotState.of(hotspot(checked: true), playerAt: school), .checkedIn)
        let far = CLLocationCoordinate2D(latitude: 48.26832 + 0.001, longitude: 14.25138) // ca. 111 m
        guard case .tooFar(let m) = HotspotState.of(hotspot(), playerAt: far) else { return XCTFail("zu weit") }
        XCTAssertTrue((100...120).contains(m), "\(m) m")
    }

    func testHotspotDecodesFromBackend() throws {
        let json = #"[{"id":"htl-leonding","name":"HTL Leonding","latitude":48.26832,"longitude":14.25138,"radiusMeters":60,"points":10,"firstOfDayBonus":15,"checkedInToday":false,"checkinsToday":2}]"#
        let list = try JSONDecoder().decode([HotspotDTO].self, from: Data(json.utf8))
        XCTAssertEqual(list.first?.checkinsToday, 2)
    }

    func testEmotesMatchTheBackendList() {
        // Backend: GameSocket.EMOTES – andere Emojis leitet der Server nicht weiter
        XCTAssertEqual(Emotes.all, ["🔥", "😤", "💪", "👀", "🏆", "😂", "👋", "🥊"])
        XCTAssertTrue(Set(Emotes.map).isSubset(of: Set(Emotes.all)))
    }

    func testEmoteMessageIsParsed() async {
        let socket = GameSocketService(playerId: "me")
        let exp = expectation(description: "emote")
        socket.onEmote = { from, emoji, battleId in
            XCTAssertEqual(from, "a")
            XCTAssertEqual(emoji, "🔥")
            XCTAssertEqual(battleId, 7)
            exp.fulfill()
        }
        socket.handleIncoming(text: #"{"type":"emote","fromId":"a","emoji":"🔥","battleId":7}"#)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testSameEmojiTwiceIsANewEvent() {
        XCTAssertNotEqual(EmoteEvent(emoji: "🔥"), EmoteEvent(emoji: "🔥"), "zweimal 🔥 ploppt zweimal auf")
    }
}
