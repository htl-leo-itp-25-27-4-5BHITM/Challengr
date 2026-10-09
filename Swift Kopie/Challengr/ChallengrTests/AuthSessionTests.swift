import XCTest
@testable import Challengr

/// Login an allen Anfragen (Checkliste A2/A4): Bearer-Token, Erneuerung, kein Token nach Abmelden.
final class AuthSessionTests: XCTestCase {

    private var session: AuthSession!

    override func setUp() {
        session = AuthSession()
    }

    func testAddsBearerToken() {
        session.update(accessToken: "abc", expiresIn: 300)
        var request = URLRequest(url: URL(string: "https://example.org/api/players/me")!)
        session.authorize(&request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer abc")
    }

    func testNoTokenNoHeader() {
        var request = URLRequest(url: URL(string: "https://example.org/api/ranks")!)
        session.authorize(&request)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testRefreshShortlyBeforeExpiry() {
        let now = Date()
        session.update(accessToken: "abc", expiresIn: 300, now: now)
        XCTAssertFalse(session.needsRefresh(now: now))
        XCTAssertTrue(session.needsRefresh(now: now.addingTimeInterval(300 - AuthSession.refreshMargin + 1)))
    }

    func testRefreshUsesTheRefresherOnce() async {
        session.update(accessToken: "old", expiresIn: 1, now: Date().addingTimeInterval(-60))
        let counter = Counter()
        session.setRefresher { [session] in
            await counter.increment()
            try? await Task.sleep(nanoseconds: 50_000_000)
            session?.update(accessToken: "new", expiresIn: 300)
            return true
        }
        async let a = session.refreshIfNeeded()
        async let b = session.refreshIfNeeded()
        let results = await [a, b]
        XCTAssertEqual(results, [true, true])
        let calls = await counter.value
        XCTAssertEqual(calls, 1, "gleichzeitige Anfragen teilen sich eine Erneuerung")
        XCTAssertEqual(session.currentToken, "new")
    }

    func testClearRemovesToken() {
        session.update(accessToken: "abc", expiresIn: 300)
        session.clear()
        XCTAssertNil(session.currentToken)
        var request = URLRequest(url: URL(string: "https://example.org")!)
        session.authorize(&request)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testWebSocketUrlCarriesNoPlayerId() {
        let url = BackendConfig.gameWebSocketURL()
        XCTAssertEqual(url.path, "/ws/game")
        XCTAssertNil(url.query, "wer verbunden ist, sagt das Token – nicht die URL")
    }

    func testOtherPlayersWithoutCoordinatesDecode() throws {
        let json = #"{"id":"b","name":"Mia","latitude":null,"longitude":null,"points":200,"rankName":"Scrapper","trophies":200}"#
        let p = try JSONDecoder().decode(PlayerDTO.self, from: Data(json.utf8))
        XCTAssertNil(p.latitude)
        XCTAssertNil(p.invisible)
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
