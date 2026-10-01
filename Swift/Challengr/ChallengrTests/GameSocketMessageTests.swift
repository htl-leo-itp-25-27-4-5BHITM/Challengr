import XCTest
@testable import Challengr

/// Server-Nachrichten, wie das Backend sie schickt → richtige Callbacks in der App.
final class GameSocketMessageTests: XCTestCase {

    private var socket: GameSocketService!

    override func setUp() async throws {
        socket = GameSocketService(playerId: "me") // verbindet sich nicht von selbst
    }

    func testBattleRequestedWithChallengeFromBackend() async {
        let exp = expectation(description: "challenge")
        socket.onChallengeReceived = { battleId, fromId, toId, challengeId, text, category, lat, lon in
            XCTAssertEqual(battleId, 5)
            XCTAssertEqual(fromId, "p-1")
            XCTAssertEqual(toId, "me")
            XCTAssertEqual(challengeId, 12)
            XCTAssertEqual(text, "Sag \"Hallo\"\nlaut")
            XCTAssertEqual(category, "Mutprobe")
            XCTAssertEqual(lat ?? 0, 48.1, accuracy: 0.0001)
            XCTAssertEqual(lon ?? 0, 14.2, accuracy: 0.0001)
            exp.fulfill()
        }
        socket.handleIncoming(text: """
        {"type":"battle-requested","battleId":5,"fromPlayerId":"p-1","toPlayerId":"me","challengeId":12,
         "challengeText":"Sag \\"Hallo\\"\\nlaut","challengeCategory":"Mutprobe","status":"REQUESTED",
         "expiresInSeconds":60,"targetLatitude":48.1,"targetLongitude":14.2}
        """)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testBattleRequestedFromOldBackendWithoutText() async {
        let exp = expectation(description: "challenge")
        socket.onChallengeReceived = { _, fromId, _, _, text, category, lat, lon in
            XCTAssertEqual(fromId, "3", "Zahl-IDs werden zu Strings")
            XCTAssertNil(text)
            XCTAssertNil(category)
            XCTAssertNil(lat)
            XCTAssertNil(lon)
            exp.fulfill()
        }
        socket.handleIncoming(text: """
        {"type":"battle-requested","battleId":1,"fromPlayerId":3,"toPlayerId":"me","challengeId":1,
         "targetLatitude":null,"targetLongitude":null}
        """)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testStatusUpdatesGoToTheRightCallback() async {
        let accepted = expectation(description: "accepted")
        let voting = expectation(description: "voting")
        let other = expectation(description: "other")
        other.expectedFulfillmentCount = 4

        var otherStatuses: [String] = []
        socket.onBattleAccepted = { id in XCTAssertEqual(id, 1); accepted.fulfill() }
        socket.onReadyForVoting = { id in XCTAssertEqual(id, 2); voting.fulfill() }
        socket.onBattleUpdatedStatus = { _, status in otherStatuses.append(status); other.fulfill() }

        socket.handleIncoming(text: #"{"type":"battle-updated","battleId":1,"status":"ACCEPTED"}"#)
        socket.handleIncoming(text: #"{"type":"battle-updated","battleId":2,"status":"READY_FOR_VOTING"}"#)
        for status in ["CANCELLED", "EXPIRED", "DECLINED", "ABANDONED"] {
            socket.handleIncoming(text: #"{"type":"battle-updated","battleId":3,"status":"\#(status)"}"#)
        }

        await fulfillment(of: [accepted, voting, other], timeout: 2)
        XCTAssertEqual(otherStatuses, ["CANCELLED", "EXPIRED", "DECLINED", "ABANDONED"])
    }

    func testBattleResultWithIdsAndMetrics() async {
        let exp = expectation(description: "result")
        socket.onBattleResult = { data in
            XCTAssertEqual(data.battleId, 9)
            XCTAssertEqual(data.winnerId, "me")
            XCTAssertEqual(data.loserId, "you")
            XCTAssertEqual(data.winnerName, "Max")
            XCTAssertEqual(data.winnerPointsDelta, 33)
            XCTAssertEqual(data.loserPointsDelta, -22)
            XCTAssertEqual(data.metrics?.sprint?.winner ?? 0, 12.5, accuracy: 0.001)
            XCTAssertEqual(data.metrics?.sprint?.loser ?? 0, 5.0, accuracy: 0.001)
            exp.fulfill()
        }
        socket.handleIncoming(text: """
        {"type":"battle-result","battleId":9,"winnerId":"me","winnerName":"Max","winnerAvatar":"x",
         "winnerPointsDelta":33,"loserId":"you","loserName":"Moritz","loserAvatar":"y","loserPointsDelta":-22,
         "trashTalk":"GG!","metrics":{"sprint":{"winner":12.50,"loser":5.00}}}
        """)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testIntegerMetrics() async {
        let exp = expectation(description: "result")
        socket.onBattleResult = { data in
            XCTAssertEqual(data.metrics?.shake?.winner, 40)
            XCTAssertEqual(data.metrics?.shake?.loser, 31)
            XCTAssertNil(data.metrics?.sprint)
            exp.fulfill()
        }
        socket.handleIncoming(text: """
        {"type":"battle-result","battleId":1,"winnerId":"a","winnerName":"A","winnerPointsDelta":30,
         "loserId":"b","loserName":"B","loserPointsDelta":-20,"trashTalk":"GG!",
         "metrics":{"shake":{"winner":40,"loser":31}}}
        """)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testDrawResultHasNoIds() async {
        let exp = expectation(description: "result")
        socket.onBattleResult = { data in
            XCTAssertNil(data.winnerId)
            XCTAssertNil(data.loserId)
            XCTAssertEqual(data.winnerName, "Niemand")
            XCTAssertEqual(data.trashTalk, "Unentschieden!")
            XCTAssertNil(data.metrics)
            exp.fulfill()
        }
        socket.handleIncoming(text: """
        {"type":"battle-result","battleId":1,"winnerId":null,"winnerName":"Niemand","winnerPointsDelta":0,
         "loserId":null,"loserName":"Niemand","loserPointsDelta":0,"trashTalk":"Unentschieden!"}
        """)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testRejectedChallengeShowsReason() async {
        let exp = expectation(description: "rejected")
        socket.onBattleRejected = { reason in
            XCTAssertEqual(reason, "Mit diesem Spieler läuft schon eine offene Challenge")
            exp.fulfill()
        }
        socket.handleIncoming(text: #"{"type":"battle-rejected","toPlayerId":"x","reason":"Mit diesem Spieler läuft schon eine offene Challenge"}"#)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testKnowledgeQuestionWithoutAnswer() async {
        let exp = expectation(description: "question")
        socket.onKnowledgeQuestion = { battleId, challenge, timeLimit in
            XCTAssertNil(timeLimit, "Altes Backend ohne Zeitlimit")
            XCTAssertEqual(battleId, 4)
            XCTAssertEqual(challenge.choices?.count, 4)
            XCTAssertNil(challenge.correctIndex, "Backend schickt die Antwort nicht mehr")
            exp.fulfill()
        }
        socket.handleIncoming(text: """
        {"type":"battle-question","battleId":4,"challenge":{"id":7,"text":"2+2?","category":"Wissen",
         "choices":["3","4","5","22"]}}
        """)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testKnowledgeQuestionCarriesTimeLimit() async {
        let exp = expectation(description: "question")
        socket.onKnowledgeQuestion = { _, _, timeLimit in
            XCTAssertEqual(timeLimit, 30)
            exp.fulfill()
        }
        socket.handleIncoming(text: #"{"type":"battle-question","battleId":4,"timeLimitSeconds":30,"challenge":{"id":7,"text":"2+2?","category":"Wissen","choices":["3","4","5","22"]}}"#)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testRunningBattleAfterRestart() async {
        let exp = expectation(description: "running")
        socket.onBattleRunning = { battleId, fromId, toId, challengeId, text, category, status in
            XCTAssertEqual(battleId, 14)
            XCTAssertEqual(fromId, "a")
            XCTAssertEqual(toId, "me")
            XCTAssertEqual(challengeId, 5)
            XCTAssertEqual(text, "Plank")
            XCTAssertEqual(category, "Fitness")
            XCTAssertEqual(status, "ACCEPTED")
            exp.fulfill()
        }
        socket.handleIncoming(text: #"{"type":"battle-running","battleId":14,"fromPlayerId":"a","toPlayerId":"me","challengeId":5,"challengeText":"Plank","challengeCategory":"Fitness","status":"ACCEPTED"}"#)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testWrongAnswerFeedback() async {
        let exp = expectation(description: "feedback")
        socket.onKnowledgeAnswerFeedback = { battleId, correct in
            XCTAssertEqual(battleId, 4)
            XCTAssertFalse(correct)
            exp.fulfill()
        }
        socket.handleIncoming(text: #"{"type":"battle-answer-feedback","battleId":4,"correct":false}"#)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testPendingAndFriendEvents() async {
        let pending = expectation(description: "pending")
        let friend = expectation(description: "friend")
        let friendUpdate = expectation(description: "friendUpdate")
        socket.onBattlePending = { id in XCTAssertEqual(id, 8); pending.fulfill() }
        socket.onFriendRequestCreated = { reqId, from, to in
            XCTAssertEqual(reqId, 11); XCTAssertEqual(from, "a"); XCTAssertEqual(to, "me")
            friend.fulfill()
        }
        socket.onFriendRequestUpdated = { _, _, _, status in
            XCTAssertEqual(status, "ACCEPTED"); friendUpdate.fulfill()
        }

        socket.handleIncoming(text: #"{"type":"battle-pending","battleId":8}"#)
        socket.handleIncoming(text: #"{"type":"friend-request-created","requestId":11,"fromPlayerId":"a","toPlayerId":"me"}"#)
        socket.handleIncoming(text: #"{"type":"friend-request-updated","requestId":11,"fromPlayerId":"a","toPlayerId":"me","status":"ACCEPTED"}"#)

        await fulfillment(of: [pending, friend, friendUpdate], timeout: 2)
    }

    func testPositionEventWithoutCoordinates() async {
        let exp = expectation(description: "position")
        socket.onPlayerPositionUpdated = { id, lat, lon in
            XCTAssertEqual(id, "p-9")
            XCTAssertNil(lat)
            XCTAssertNil(lon)
            exp.fulfill()
        }
        socket.handleIncoming(text: #"{"type":"player-position-updated","playerId":"p-9"}"#)
        await fulfillment(of: [exp], timeout: 2)
    }

    func testBrokenOrUnknownMessagesAreIgnored() async {
        let nothing = expectation(description: "no callback")
        nothing.isInverted = true
        socket.onChallengeReceived = { _, _, _, _, _, _, _, _ in nothing.fulfill() }
        socket.onBattleResult = { _ in nothing.fulfill() }
        socket.onBattleUpdatedStatus = { _, _ in nothing.fulfill() }

        socket.handleIncoming(text: "kein json")
        socket.handleIncoming(text: "[]")
        socket.handleIncoming(text: #"{"ohne":"type"}"#)
        socket.handleIncoming(text: #"{"type":"gibts-nicht"}"#)
        socket.handleIncoming(text: #"{"type":"error","message":"Unknown type"}"#)

        await fulfillment(of: [nothing], timeout: 0.5)
    }
}
