import XCTest
import SceneKit
@testable import Challengr

/// Liga (Wissen / Real-Life) und Friendly: Modus, Quiz-Show und Server-Nachrichten.
final class LeagueModeTests: XCTestCase {

    // MARK: - Modus

    func testModeFromServer() {
        XCTAssertEqual(BattleMode(serverValue: "RANKED_KNOWLEDGE"), .rankedKnowledge)
        XCTAssertEqual(BattleMode(serverValue: "RANKED_REALLIFE"), .rankedRealLife)
        XCTAssertEqual(BattleMode(serverValue: "FRIENDLY"), .friendly)
        XCTAssertEqual(BattleMode(serverValue: nil), .friendly, "alte Server → Friendly")
        XCTAssertEqual(BattleMode(serverValue: "QUATSCH"), .friendly)
    }

    func testOnlyLeaguesAreRanked() {
        XCTAssertTrue(BattleMode.rankedKnowledge.isRanked)
        XCTAssertTrue(BattleMode.rankedRealLife.isRanked)
        XCTAssertFalse(BattleMode.friendly.isRanked)
    }

    func testTrophyTexts() {
        // Eine Liga: beide Spielarten zählen auf dieselben Trophäen
        XCTAssertEqual(BattleMode.rankedKnowledge.trophyText(delta: 28), "+28 Trophäen")
        XCTAssertEqual(BattleMode.rankedRealLife.trophyText(delta: -20), "-20 Trophäen")
        XCTAssertTrue(BattleMode.rankedKnowledge.title.hasPrefix("Liga"))
        XCTAssertTrue(BattleMode.rankedRealLife.title.hasPrefix("Liga"))
        XCTAssertEqual(BattleMode.friendly.trophyText(delta: 50), "Friendly – es ging um nichts")
    }

    func testResultLabels() {
        var r = BattleResultData(winnerName: "A", winnerAvatar: "", winnerPointsDelta: 28,
                                 loserName: "B", loserAvatar: "", loserPointsDelta: -20,
                                 trashTalk: "", metrics: nil)
        XCTAssertEqual(r.deltaLabel(28), "FRIENDLY")
        XCTAssertNil(r.quizScoreLine)
        r.mode = .rankedKnowledge
        r.quizFromScore = 320
        r.quizToScore = 210
        r.participants = BattleParticipants(fromId: "1", toId: "2", fromName: "Basti", toName: "Mia")
        XCTAssertEqual(r.deltaLabel(28), "+28 🏆")
        XCTAssertEqual(r.deltaLabel(-20), "-20 🏆")
        XCTAssertEqual(r.quizScoreLine, "Basti 320 : 210 Mia")
    }

    func testPlayerWithLeagueTrophiesDecodes() throws {
        let json = #"{"id":"p","name":"Mia","latitude":48.2,"longitude":14.2,"points":230,"rankName":"Scrapper","trophies":245}"#
        let p = try JSONDecoder().decode(PlayerDTO.self, from: Data(json.utf8))
        XCTAssertEqual(p.trophies, 245)
        XCTAssertEqual(p.points, 230, "Punkte bleiben die Währung")
        let old = #"{"id":"p","name":"Mia","latitude":48.2,"longitude":14.2,"points":230,"rankName":"Scrapper"}"#
        XCTAssertNil(try JSONDecoder().decode(PlayerDTO.self, from: Data(old.utf8)).trophies, "alter Server")
    }

    // MARK: - Quiz-Show

    private func question(round: Int, battleId: Int64 = 7, remainingMs: Int = 15_000,
                          scores: [String: Int] = [:]) -> QuizQuestion {
        QuizQuestion(battleId: battleId, round: round, rounds: 4, timeLimitSeconds: 15, remainingMs: remainingMs,
                     questionId: Int64(round), text: "Frage \(round)", choices: ["a", "b", "c", "d"], scores: scores)
    }

    func testQuizQuestionParsing() {
        let q = QuizQuestion.parse([
            "type": "quiz-question", "battleId": 7, "round": 2, "rounds": 4, "timeLimitSeconds": 15,
            "remainingMs": 9000, "question": ["id": 33, "text": "Hauptstadt?", "choices": ["A", "B", "C", "D"]],
            "scores": ["me": 140, "p-2": 0]
        ])
        XCTAssertEqual(q?.round, 2)
        XCTAssertEqual(q?.remainingMs, 9000)
        XCTAssertEqual(q?.questionId, 33)
        XCTAssertEqual(q?.choices.count, 4)
        XCTAssertEqual(q?.scores["me"], 140)
        XCTAssertNil(QuizQuestion.parse(["battleId": 7]), "ohne Frage kein Quiz")
    }

    func testQuizRoundResultParsing() {
        let r = QuizRoundResult.parse([
            "battleId": 7, "round": 4, "rounds": 4, "correctIndex": 2, "last": true,
            "answers": ["me": ["answerIndex": 2, "points": 140], "p-2": ["answerIndex": -1, "points": 0]],
            "scores": ["me": 400, "p-2": 250]
        ])
        XCTAssertEqual(r?.correctIndex, 2)
        XCTAssertEqual(r?.last, true)
        XCTAssertEqual(r?.answers["me"], .init(answerIndex: 2, points: 140))
        XCTAssertEqual(r?.answers["p-2"]?.answerIndex, -1)
    }

    func testQuizFlowThroughARound() {
        let model = QuizShowModel(ownPlayerId: "me")
        let now = Date()
        model.start(battleId: 7)
        XCTAssertEqual(model.phase, .intro)

        model.receive(question(round: 1), now: now)
        XCTAssertEqual(model.phase, .question)
        XCTAssertEqual(model.secondsLeft(now: now), 15)
        XCTAssertEqual(model.timeFraction(now: now.addingTimeInterval(7.5)), 0.5, accuracy: 0.01)

        model.opponentDidAnswer(battleId: 7, round: 1)
        XCTAssertTrue(model.opponentAnswered)

        let answer = model.answer(2, now: now.addingTimeInterval(3))
        XCTAssertEqual(answer?.round, 1)
        XCTAssertEqual(answer?.index, 2)
        XCTAssertNil(model.answer(1, now: now.addingTimeInterval(4)), "nur die erste Antwort zählt")

        model.receive(QuizRoundResult(battleId: 7, round: 1, rounds: 4, correctIndex: 2, last: false,
                                      answers: ["me": .init(answerIndex: 2, points: 140),
                                                "p-2": .init(answerIndex: 0, points: 0)],
                                      scores: ["me": 140, "p-2": 0]))
        XCTAssertEqual(model.phase, .reveal)
        XCTAssertEqual(model.myRoundPoints, 140)
        XCTAssertEqual(model.opponentRoundAnswer, 0)
        XCTAssertEqual(model.ownScore, 140)
        XCTAssertEqual(model.opponentScore, 0)

        // Nächste Runde: Antwort und Gegner-Haken zurückgesetzt
        model.receive(question(round: 2, scores: ["me": 140, "p-2": 0]), now: now)
        XCTAssertEqual(model.phase, .question)
        XCTAssertNil(model.myAnswer)
        XCTAssertFalse(model.opponentAnswered)
    }

    func testNoAnswerAfterTimeIsUp() {
        let model = QuizShowModel(ownPlayerId: "me")
        let now = Date()
        model.receive(question(round: 1, remainingMs: 2000), now: now)
        XCTAssertNil(model.answer(0, now: now.addingTimeInterval(3)))
        XCTAssertTrue(model.isTimeUp(now: now.addingTimeInterval(3)))
    }

    func testResultsOfOtherBattlesAreIgnored() {
        let model = QuizShowModel(ownPlayerId: "me")
        model.receive(question(round: 1))
        model.receive(QuizRoundResult(battleId: 99, round: 1, rounds: 4, correctIndex: 0, last: false,
                                      answers: [:], scores: ["me": 500]))
        XCTAssertEqual(model.phase, .question)
        XCTAssertEqual(model.ownScore, 0)
        model.opponentDidAnswer(battleId: 99, round: 1)
        XCTAssertFalse(model.opponentAnswered)
    }

    func testRestartedQuestionKeepsOwnAnswer() {
        // Nach einem Neustart schickt der Server dieselbe Runde erneut (mit weniger Restzeit)
        let model = QuizShowModel(ownPlayerId: "me")
        let now = Date()
        model.receive(question(round: 3), now: now)
        _ = model.answer(1, now: now)
        model.receive(question(round: 3, remainingMs: 5000), now: now)
        XCTAssertEqual(model.myAnswer, 1)
        XCTAssertEqual(model.secondsLeft(now: now), 5)
    }

    func testNewBattleResetsTheShow() {
        let model = QuizShowModel(ownPlayerId: "me")
        model.receive(question(round: 2, scores: ["me": 120, "p-2": 80]))
        XCTAssertEqual(model.ownScore, 120)
        model.start(battleId: 8)
        XCTAssertEqual(model.phase, .intro)
        XCTAssertEqual(model.ownScore, 0)
        XCTAssertNil(model.question)
    }

    // MARK: - 3D-Studio

    func testQuizmasterIsNeverOneOfThePlayers() {
        XCTAssertEqual(QuizStageView.host(own: .junge, opponent: .maedchen), .merlo)
        XCTAssertEqual(QuizStageView.host(own: .merlo, opponent: .maedchen), .sirBrecht)
        XCTAssertEqual(QuizStageView.host(own: .merlo, opponent: .sirBrecht), .kaeptnRex)
    }

    func testStudioBuildsWithAllThreeFigures() throws {
        let studio = try XCTUnwrap(QuizStudio.build(own: .junge, opponent: .maedchen, host: .merlo))
        XCTAssertNotNil(studio.camera.camera)
        XCTAssertLessThan(studio.ownActor.position.x, 0, "eigenes Pult links")
        XCTAssertGreaterThan(studio.opponentActor.position.x, 0, "Gegner rechts")
        // Ereignisse laufen ohne Absturz durch
        for kind: QuizStageEvent.Kind in [.intro, .question(round: 1), .answered(own: true),
                                          .reveal(ownCorrect: true, opponentCorrect: false), .finished(ownWins: nil)] {
            studio.play(kind)
        }
    }

    // MARK: - Server-Nachrichten

    func testModeOfARequestIsRemembered() async {
        let socket = GameSocketService(playerId: "me")
        let exp = expectation(description: "challenge")
        socket.onChallengeReceived = { _, _, _, _, _, _, _, _ in exp.fulfill() }
        socket.handleIncoming(text: """
        {"type":"battle-requested","battleId":5,"fromPlayerId":"p-1","toPlayerId":"me","challengeId":0,
         "challengeText":"Quiz-Show: 4 Fragen","challengeCategory":"Wissen","mode":"RANKED_KNOWLEDGE"}
        """)
        await fulfillment(of: [exp], timeout: 2)
        XCTAssertEqual(socket.modeByBattle[5], .rankedKnowledge)
    }

    func testQuizMessagesReachTheCallbacks() async {
        let socket = GameSocketService(playerId: "me")
        let q = expectation(description: "question")
        let r = expectation(description: "result")
        let o = expectation(description: "opponent answered")
        let f = expectation(description: "opponent finished")
        socket.onQuizQuestion = { XCTAssertEqual($0.round, 1); q.fulfill() }
        socket.onQuizRoundResult = { XCTAssertEqual($0.correctIndex, 3); r.fulfill() }
        socket.onQuizOpponentAnswered = { battleId, round in
            XCTAssertEqual(battleId, 5); XCTAssertEqual(round, 1); o.fulfill()
        }
        socket.onOpponentFinished = { XCTAssertEqual($0, 6); f.fulfill() }

        socket.handleIncoming(text: """
        {"type":"quiz-question","battleId":5,"round":1,"rounds":4,"timeLimitSeconds":15,"remainingMs":15000,
         "question":{"id":3,"text":"?","choices":["a","b","c","d"]},"scores":{"me":0,"p-1":0}}
        """)
        socket.handleIncoming(text: #"{"type":"quiz-opponent-answered","battleId":5,"round":1}"#)
        socket.handleIncoming(text: """
        {"type":"quiz-round-result","battleId":5,"round":1,"rounds":4,"correctIndex":3,"last":false,
         "answers":{"me":{"answerIndex":3,"points":150}},"scores":{"me":150,"p-1":0}}
        """)
        socket.handleIncoming(text: #"{"type":"opponent-finished","battleId":6}"#)
        await fulfillment(of: [q, o, r, f], timeout: 2)
    }
}
