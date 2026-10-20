import XCTest
import SwiftUI
@testable import Challengr

final class QuestTests: XCTestCase {

    static let json = """
    {"coins":340,"day":"2026-10-20","resetsAt":"2026-10-20T22:00:00Z",
     "daily":[{"id":"VISIT","title":"Schau heute bei Challengr vorbei","icon":"hand.wave.fill","target":1,"progress":1,"coins":10,"claimed":true},
              {"id":"WIN_1","title":"Gewinne 1 Liga-Battle","icon":"trophy.fill","target":1,"progress":1,"coins":30,"claimed":false},
              {"id":"PLAY_2","title":"Spiele 2 Battles","icon":"bolt.fill","target":2,"progress":1,"coins":20,"claimed":false}],
     "events":[{"id":"beta","title":"Beta-Event: Crash-Test","subtitle":"Nur in der Testphase – danach nie wieder!",
       "startsOn":"2026-10-13","endsOn":"2026-11-30","active":true,"rewardCharacter":"crash-dummy","rewardCoins":100,
       "tasks":[{"id":"DAYS_5","title":"Spiele an 5 verschiedenen Tagen","icon":"calendar","target":5,"progress":3,"coins":0,"claimed":false},
                {"id":"BATTLES_10","title":"Spiele 10 Battles","icon":"bolt.fill","target":10,"progress":10,"coins":0,"claimed":false},
                {"id":"QUIZ_3","title":"Spiele 3 Quiz-Shows","icon":"brain.head.profile","target":3,"progress":1,"coins":0,"claimed":false},
                {"id":"CHECKINS_2","title":"Check 2× am Hotspot ein","icon":"mappin.and.ellipse","target":2,"progress":0,"coins":0,"claimed":false},
                {"id":"FRIENDS_1","title":"Finde mindestens 1 Freund","icon":"person.badge.plus","target":1,"progress":1,"coins":0,"claimed":false},
                {"id":"DAILY_6","title":"Erledige 6 Tagesaufgaben","icon":"checklist","target":6,"progress":2,"coins":0,"claimed":false}],
       "completed":false,"claimed":false}]}
    """

    func board() throws -> QuestBoard {
        try JSONDecoder().decode(QuestBoard.self, from: Data(Self.json.utf8))
    }

    func testDecodesAndCountsClaimable() throws {
        let b = try board()
        XCTAssertEqual(b.coins, 340)
        XCTAssertEqual(b.claimable, 1, "nur WIN_1 ist geschafft und nicht abgeholt")
        XCTAssertEqual(b.events.first?.character, .crashDummy)
        XCTAssertEqual(b.events.first?.doneCount, 2)
        XCTAssertNotNil(b.resetDate)
        XCTAssertNotNil(b.events.first?.endDate)
    }

    func testDurationText() {
        let now = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(QuestsView.duration(until: now.addingTimeInterval(3 * 86_400 + 60), now: now), "3 Tagen")
        XCTAssertEqual(QuestsView.duration(until: now.addingTimeInterval(5 * 3600 + 12 * 60), now: now), "5 Std. 12 Min.")
        XCTAssertEqual(QuestsView.duration(until: now.addingTimeInterval(30), now: now), "1 Min.")
    }

    /// Bilder der Ansicht für die Durchsicht (nur wenn QUEST_SNAPSHOT_DIR gesetzt ist).
    @MainActor
    func testSnapshot() throws {
        guard let dir = ProcessInfo.processInfo.environment["QUEST_SNAPSHOT_DIR"] else { throw XCTSkip("nur auf Wunsch") }
        for tab in QuestsView.Tab.allCases {
            let view = QuestsView(tab: tab, board: try board(), scrolls: false).frame(width: 393, height: tab == .events ? 1050 : 852).environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let data = try XCTUnwrap(renderer.uiImage?.pngData())
            try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("quests_\(tab.rawValue).png"))
        }
    }
}
