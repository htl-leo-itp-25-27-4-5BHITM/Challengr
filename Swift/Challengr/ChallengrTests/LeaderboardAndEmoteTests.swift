import XCTest
@testable import Challengr

final class LeaderboardAndEmoteTests: XCTestCase {

    func testLeaderboardDecodesServerJSON() throws {
        let json = """
        {"school":[{"place":1,"playerId":"a","name":"Anna","trophies":1400,"rankName":"Dueler","character":"kage","me":false}],
         "friends":[{"place":7,"playerId":"me","name":"Ich","trophies":300,"rankName":"Scrapper","character":null,"me":true}],
         "me":{"place":7,"playerId":"me","name":"Ich","trophies":300,"rankName":"Scrapper","character":null,"me":true},
         "totalPlayers":42}
        """.data(using: .utf8)!
        let board = try JSONDecoder().decode(Leaderboard.self, from: json)
        XCTAssertEqual(board.school.first?.name, "Anna")
        XCTAssertEqual(board.me?.place, 7)
        XCTAssertFalse(board.meIsInTop)
        XCTAssertEqual(board.totalPlayers, 42)
    }

    func testEmoteFavoritesAddToFrontAndKeepFour() {
        let start = ["👋", "🔥", "😤", "💪"]
        XCTAssertEqual(EmoteFavorites.adding("😎", to: start), ["😎", "👋", "🔥", "😤"])
        XCTAssertEqual(EmoteFavorites.adding("🔥", to: start), start)
    }

    func testEmoteFavoritesFallBackToDefaultForUnknownEmojis() {
        let defaults = UserDefaults(suiteName: "emote-test-\(UUID())")!
        defaults.set(["💩", "👋"], forKey: EmoteFavorites.key)
        XCTAssertEqual(EmoteFavorites.load(defaults: defaults), Emotes.map)
        EmoteFavorites.save(["😎", "👋", "🔥", "😤"], defaults: defaults)
        XCTAssertEqual(EmoteFavorites.load(defaults: defaults), ["😎", "👋", "🔥", "😤"])
    }
}
