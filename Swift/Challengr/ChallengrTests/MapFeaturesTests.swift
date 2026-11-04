import XCTest
import CoreLocation
import UIKit
import ImageIO
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
        XCTAssertEqual(Emotes.all, ["🔥", "😤", "💪", "👀", "🏆", "😂", "👋", "🥊", "😎", "🤝", "👏", "🙌", "😅", "🤔", "😱", "🥳", "🎉", "⚡", "🧠", "🏃", "👑", "🤯", "😴", "🙏"])
        XCTAssertEqual(Set(Emotes.all).count, Emotes.all.count)
        XCTAssertTrue(Set(Emotes.map).isSubset(of: Set(Emotes.all)))
    }

    func testEmoteMessageIsParsed() async {
        let socket = GameSocketService(playerId: "me")
        let exp = expectation(description: "emote")
        socket.onEmote = { from, event, battleId in
            XCTAssertEqual(from, "a")
            XCTAssertEqual(event.emoji, "🔥")
            XCTAssertNil(event.sticker)
            XCTAssertEqual(battleId, 7)
            exp.fulfill()
        }
        socket.handleIncoming(text: #"{"type":"emote","fromId":"a","emoji":"🔥","battleId":7}"#)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testSameEmojiTwiceIsANewEvent() {
        XCTAssertNotEqual(EmoteEvent(emoji: "🔥"), EmoteEvent(emoji: "🔥"), "zweimal 🔥 ploppt zweimal auf")
    }

    func testStickersMatchTheBackendList() {
        // Backend: StickerCatalog.FALLBACK (Sticker-ID → Ersatz-Emoji für alte Apps)
        let backend = ["aura": "🔥", "gogogo": "⚡", "1hit": "🥊", "locked": "😤", "mvp": "🏆", "schularbeit": "😴",
                       "vorbei": "💪", "farming": "😎", "skillissue": "😂", "oida": "😤", "minusaura": "😅", "brodachte": "😂",
                       "diskussion": "👑", "baba": "👋", "hue": "🤔", "crazy": "🤯", "1v1": "🥊", "bigbrain": "🧠",
                       "zauber": "⚡", "naechste": "👀"]
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: Stickers.all.map { ($0.id, $0.fallbackEmoji) }), backend)
        XCTAssertEqual(Stickers.all.first?.id, "aura", "Reihenfolge wie in der Übersicht")
        for sticker in Stickers.all {
            XCTAssertTrue(Emotes.all.contains(sticker.fallbackEmoji), sticker.id)
            XCTAssertNotNil(UIImage(named: sticker.assetName), "Bild \(sticker.assetName) fehlt")
        }
    }

    func testAnimatedStickersHaveSeveralFrames() throws {
        XCTAssertEqual(Stickers.animatedIds, ["aura", "gogogo", "1hit", "oida", "crazy", "farming"])
        for id in Stickers.animatedIds {
            let data = try XCTUnwrap(Stickers.byId(id)?.animationData, "Animation \(id) fehlt")
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            XCTAssertGreaterThan(CGImageSourceGetCount(source), 10, id)
        }
        XCTAssertNil(Stickers.byId("mvp")?.animationData, "nicht jeder Sticker bewegt sich")
    }

    func testStickerMessageIsParsed() async {
        let socket = GameSocketService(playerId: "me")
        let exp = expectation(description: "sticker")
        socket.onEmote = { from, event, battleId in
            XCTAssertEqual(from, "a")
            XCTAssertEqual(event.sticker?.id, "oida")
            XCTAssertEqual(event.emoji, "😤")
            XCTAssertNil(battleId)
            exp.fulfill()
        }
        socket.handleIncoming(text: #"{"type":"emote","fromId":"a","emoji":"😤","sticker":"oida","battleId":null}"#)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testUnknownStickerFallsBackToTheEmoji() async {
        // neuerer Server mit Stickern, die diese App-Version noch nicht hat
        let socket = GameSocketService(playerId: "me")
        let exp = expectation(description: "fallback")
        socket.onEmote = { _, event, _ in
            XCTAssertNil(event.sticker)
            XCTAssertEqual(event.emoji, "🎉")
            exp.fulfill()
        }
        socket.handleIncoming(text: #"{"type":"emote","fromId":"a","emoji":"🎉","sticker":"neu-im-update","battleId":null}"#)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testEmoteTokens() {
        let sticker = EmoteEvent(token: "stk:aura")
        XCTAssertEqual(sticker.sticker?.id, "aura")
        XCTAssertEqual(sticker.emoji, "🔥", "Ersatz-Emoji geht mit")
        XCTAssertEqual(sticker.visibleSeconds, Stickers.visibleSeconds)
        let emoji = EmoteEvent(token: "👋")
        XCTAssertNil(emoji.sticker)
        XCTAssertEqual(emoji.visibleSeconds, Emotes.visibleSeconds)
        XCTAssertNil(Stickers.from(token: "stk:gibtsnicht"))
        XCTAssertEqual(Emotes.spokenName("stk:oida"), "Sticker: Oida")
        XCTAssertEqual(Emotes.spokenName("🔥"), "🔥")
    }
}

/// Hotspot-Countdown und Freischalt-Texte.
final class ScheduleAndUnlockTextTests: XCTestCase {
    private func vienna(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = HotspotSchedule.zone
        return c.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testNextCheckinIsMidnightInVienna() {
        let now = vienna(2026, 10, 6, 16, 48)
        XCTAssertEqual(HotspotSchedule.nextCheckin(after: now), vienna(2026, 10, 7, 0, 0))
        XCTAssertEqual(HotspotSchedule.remainingText(until: vienna(2026, 10, 7, 0, 0), now: now), "7 Std 12 Min")
        XCTAssertEqual(HotspotSchedule.shortText(until: vienna(2026, 10, 7, 0, 0), now: now), "7:12")
        XCTAssertEqual(HotspotSchedule.remainingText(until: now.addingTimeInterval(300), now: now), "5 Min")
    }

    func testHotspotDataIsStaleAfterMidnight() {
        let loaded = vienna(2026, 10, 6, 23, 50)
        XCTAssertFalse(HotspotSchedule.isStale(loadedAt: loaded, now: vienna(2026, 10, 6, 23, 59)))
        XCTAssertTrue(HotspotSchedule.isStale(loadedAt: loaded, now: vienna(2026, 10, 7, 0, 1)))
    }

    func testUnlockTexts() {
        XCTAssertEqual(GameCharacter.sirBrecht.requirement.text(), "1 Sieg")
        XCTAssertEqual(GameCharacter.ragnar.requirement.text(progress: 1), "1/3 Siege")
        XCTAssertEqual(GameCharacter.merlo.requirement.text(progress: 7), "3/3 Quiz-Siege")
        XCTAssertEqual(GameCharacter.lyra.requirement.text(progress: 2), "2/5 Check-ins")
        XCTAssertEqual(GameCharacter.kaeptnRex.requirement.text(progress: 200), "Rang Contender · 200/350")
        XCTAssertEqual(GameCharacter.kage.requirement.text(), "Rang Dueler")
        XCTAssertEqual(GameCharacter.rankRewards(atTrophies: 600), [.hayato])
        XCTAssertEqual(GameCharacter.junge.requirement.text(), "Frei")
    }

    func testFallbackOpponentIsTheOtherStarter() {
        XCTAssertTrue([GameCharacter.junge, .maedchen].contains(GameCharacter.own))
        XCTAssertTrue([GameCharacter.junge, .maedchen].contains(GameCharacter.opponent))
    }
}

/// Karte mit einem Finger drehen (wie Pokémon GO) und Figuren-Farben.
final class MapRotationTests: XCTestCase {
    func testFingerAngleAroundCenter() {
        let c = CGPoint(x: 200, y: 400)
        XCTAssertEqual(MapRotation.angle(of: CGPoint(x: 300, y: 400), around: c), 0, accuracy: 0.001, "rechts")
        XCTAssertEqual(MapRotation.angle(of: CGPoint(x: 200, y: 500), around: c), 90, accuracy: 0.001, "unten (Uhrzeigersinn)")
    }

    func testShortestDeltaAcrossTheSeam() {
        XCTAssertEqual(MapRotation.shortestDelta(from: 170, to: -170), 20, accuracy: 0.001)
        XCTAssertEqual(MapRotation.shortestDelta(from: -170, to: 170), -20, accuracy: 0.001)
        XCTAssertEqual(MapRotation.shortestDelta(from: 10, to: 40), 30, accuracy: 0.001)
    }

    func testClockwiseFingerTurnsMapAndWraps() {
        XCTAssertEqual(MapRotation.heading(start: 90, turnedDegrees: 40), 50, accuracy: 0.001)
        XCTAssertEqual(MapRotation.heading(start: 10, turnedDegrees: 40), 330, accuracy: 0.001, "unter 0 → 330")
        XCTAssertEqual(MapRotation.heading(start: 350, turnedDegrees: -40), 30, accuracy: 0.001, "über 360 → 30")
    }

    func testShopIsOffButGiftsAreOn() {
        XCTAssertTrue(FriendGifts.isEnabled, "seit 04.11.: Geschenke mit Stickern")
        XCTAssertFalse(ShopView.isOpen)
    }
}
