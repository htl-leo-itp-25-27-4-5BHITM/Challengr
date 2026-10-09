package boundary;

import com.fasterxml.jackson.databind.JsonNode;
import control.BattleRepository;
import control.ChallengeRepository;
import control.PlayerRepository;
import entity.Player;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.common.http.TestHTTPResource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.*;

/**
 * End-to-End über echte WebSocket-Verbindungen.
 * demo-1 fordert demo-2 heraus; Spieler "3" ist verbunden, aber unbeteiligt.
 */
@QuarkusTest
class GameSocketTest {

    private static final String A = "demo-1";
    private static final String B = "demo-2";
    private static final String BYSTANDER = "3";

    @TestHTTPResource("/ws/game")
    URI wsUri;

    @Inject
    BattleRepository battleRepository;

    @Inject
    ChallengeRepository challengeRepository;

    @Inject
    PlayerRepository playerRepository;

    @Inject
    BattleRequestExpiryJob expiryJob;

    private final List<WsTestClient> clients = new ArrayList<>();

    private WsTestClient connect(String playerId) throws Exception {
        WsTestClient client = WsTestClient.connect(wsUri, playerId);
        clients.add(client);
        return client;
    }

    @BeforeEach
    void cleanState() {
        GameSocket.resultWait = GameSocket.DEFAULT_RESULT_WAIT;
        GameSocket.knowledgeTimeLimit = GameSocket.DEFAULT_KNOWLEDGE_TIME_LIMIT;
        GameSocket.quizRoundTime = GameSocket.DEFAULT_QUIZ_ROUND_TIME;
        GameSocket.quizRevealPause = GameSocket.DEFAULT_QUIZ_REVEAL;
        GameSocket.quizIntro = GameSocket.DEFAULT_QUIZ_INTRO;
        // Keine offenen oder laufenden Battles aus anderen Tests
        QuarkusTransaction.requiringNew().run(() -> battleRepository.update(
                "status = 'EXPIRED' where status not in ('DONE','EXPIRED','CANCELLED','DECLINED','ABANDONED')"));
    }

    @AfterEach
    void disconnect() throws Exception {
        GameSocket.resultWait = GameSocket.DEFAULT_RESULT_WAIT;
        for (WsTestClient c : clients) c.close();
    }

    // ---------------------------------------------------------------- A4: nur mit Login

    @Test
    void connectionWithoutLoginIsRefused() throws Exception {
        WsTestClient anonymous;
        try {
            anonymous = WsTestClient.connect(wsUri, null, B, "?playerId=" + B);
        } catch (Exception refused) {
            return; // schon das Upgrade wird mit 401 abgelehnt
        }
        clients.add(anonymous);
        long deadline = System.currentTimeMillis() + 3000;
        while (anonymous.session.isOpen() && System.currentTimeMillis() < deadline) Thread.sleep(50);
        assertFalse(anonymous.session.isOpen(), "ohne Login wird die Verbindung geschlossen");
    }

    @Test
    void foreignPlayerIdInTheUrlDoesNotTakeOverTheSession() throws Exception {
        WsTestClient realB = connect(B);
        WsTestClient bystander = connect(BYSTANDER);
        // Angemeldet als A, aber ?playerId=B in der URL
        WsTestClient attacker = WsTestClient.connect(wsUri, A, B, "?playerId=" + B);
        clients.add(attacker);
        Thread.sleep(300);
        assertTrue(realB.session.isOpen(), "die Session von B bleibt bestehen");

        // Was der Angreifer schickt, gilt als A – auch mit gefälschtem fromId wird abgelehnt
        attacker.send("{\"type\":\"create-battle\",\"fromId\":\"" + B + "\",\"toId\":\"" + BYSTANDER + "\",\"challengeId\":1}");
        assertNotNull(attacker.await("battle-rejected", 3), "fremder Absender wird abgelehnt");
        assertNull(bystander.await("battle-requested", 1), "keine Anfrage im Namen von B");

        attacker.send("{\"type\":\"create-battle\",\"toId\":\"" + BYSTANDER + "\",\"challengeId\":1}");
        var request = bystander.await("battle-requested", 3);
        assertNotNull(request);
        assertEquals(A, request.path("fromPlayerId").asText(), "Session gehört dem angemeldeten Spieler A");
    }

    // ---------------------------------------------------------------- helpers

    private String create(long challengeId) {
        return "{\"type\":\"create-battle\",\"fromId\":\"" + A + "\",\"toId\":\"" + B + "\",\"challengeId\":" + challengeId + "}";
    }

    private static String status(long battleId, String status) {
        return "{\"type\":\"update-battle-status\",\"battleId\":" + battleId + ",\"status\":\"" + status + "\"}";
    }

    private long request(WsTestClient attacker, WsTestClient defender, long challengeId) throws Exception {
        attacker.send(create(challengeId));
        JsonNode requested = defender.await("battle-requested", 5);
        assertNotNull(requested, "Empfänger bekommt die Anfrage");
        return requested.get("battleId").asLong();
    }

    private long createAcceptedBattle(WsTestClient attacker, WsTestClient defender, long challengeId) throws Exception {
        long battleId = request(attacker, defender, challengeId);
        defender.send(status(battleId, "ACCEPTED"));
        assertNotNull(attacker.awaitStatus("ACCEPTED", 5));
        return battleId;
    }

    private long createAcceptedBattle(WsTestClient attacker, WsTestClient defender) throws Exception {
        return createAcceptedBattle(attacker, defender, 1L);
    }

    private String createMode(String mode) {
        return "{\"type\":\"create-battle\",\"fromId\":\"" + A + "\",\"toId\":\"" + B + "\",\"mode\":\"" + mode + "\"}";
    }

    private long createAcceptedRanked(WsTestClient attacker, WsTestClient defender, String mode) throws Exception {
        attacker.send(createMode(mode));
        JsonNode requested = defender.await("battle-requested", 5);
        assertNotNull(requested);
        long battleId = requested.get("battleId").asLong();
        defender.send(status(battleId, "ACCEPTED"));
        assertNotNull(attacker.awaitStatus("ACCEPTED", 5));
        return battleId;
    }

    private static String quizAnswer(long battleId, int round, int index) {
        return "{\"type\":\"quiz-answer\",\"battleId\":" + battleId + ",\"round\":" + round + ",\"answerIndex\":" + index + "}";
    }

    private int correctIndexFor(long challengeId) {
        return QuarkusTransaction.requiringNew().call(() -> challengeRepository.findById(challengeId).getCorrectIndex());
    }

    private int trophies(String playerId) {
        return QuarkusTransaction.requiringNew().call(() -> playerRepository.findById(playerId).getTrophies());
    }

    private int points(String playerId) {
        return QuarkusTransaction.requiringNew().call(() -> playerRepository.findById(playerId).getPoints());
    }

    private long wissenChallengeId() {
        return challengeRepository.findChallengesByKat("Wissen").get(0).getId();
    }

    // ------------------------------------------------------- Ergebnis-Empfänger

    @Test
    void resultOnlyReachesTheTwoPlayers() throws Exception {
        WsTestClient attacker  = connect(A);
        WsTestClient defender  = connect(B);
        WsTestClient bystander = connect(BYSTANDER);

        long battleId = createAcceptedBattle(attacker, defender);

        // Angreifer gibt auf → Verteidiger gewinnt
        attacker.send(status(battleId, "DONE_SURRENDER"));

        JsonNode resultA = attacker.await("battle-result", 5);
        JsonNode resultD = defender.await("battle-result", 5);
        assertNotNull(resultA);
        assertNotNull(resultD);
        assertEquals(B, resultD.get("winnerId").asText());
        assertEquals(A, resultD.get("loserId").asText());

        assertNull(bystander.await("battle-result", 1), "Unbeteiligter Spieler darf kein Ergebnis bekommen");
    }

    @Test
    void surrenderInTheLeagueGivesTrophiesToTheOtherPlayer() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        int pointsBefore = points(B);
        int trophiesBefore = trophies(B);

        long battleId = createAcceptedRanked(attacker, defender, "RANKED_REALLIFE");
        attacker.send(status(battleId, "DONE_SURRENDER"));

        JsonNode result = defender.await("battle-result", 5);
        assertNotNull(result);
        assertEquals("RANKED_REALLIFE", result.get("mode").asText());
        int delta = result.get("winnerPointsDelta").asInt();
        assertTrue(delta > 0);
        assertEquals(trophiesBefore + delta, trophies(B), "Liga-Trophäen steigen");
        assertEquals(pointsBefore + delta, points(B), "Sieger bekommt den Gewinn auch als Punkte");
    }

    @Test
    void friendlyIsForNothing() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        int pointsBefore = points(B), trophiesBefore = trophies(B);

        long battleId = createAcceptedBattle(attacker, defender); // ohne Modus = Friendly
        attacker.send(status(battleId, "DONE_SURRENDER"));

        JsonNode result = defender.await("battle-result", 5);
        assertNotNull(result);
        assertEquals("FRIENDLY", result.get("mode").asText());
        assertEquals(B, result.get("winnerId").asText());
        assertEquals(0, result.get("winnerPointsDelta").asInt());
        assertEquals(pointsBefore, points(B));
        assertEquals(trophiesBefore, trophies(B));
    }

    @Test
    void friendlyBothFinishedIsADraw() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        long battleId = createAcceptedBattle(attacker, defender);

        attacker.send("{\"type\":\"friendly-finished\",\"battleId\":" + battleId + "}");
        assertNotNull(defender.await("opponent-finished", 5), "Gegner sieht, dass ich fertig bin");
        defender.send("{\"type\":\"friendly-finished\",\"battleId\":" + battleId + "}");

        JsonNode result = attacker.await("battle-result", 5);
        assertNotNull(result);
        assertEquals("DRAW", result.get("outcome").asText());
    }

    @Test
    void realLifeLeaguePicksAMeasuredChallenge() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        attacker.send(createMode("RANKED_REALLIFE"));
        JsonNode requested = defender.await("battle-requested", 5);
        assertNotNull(requested);
        assertEquals("RANKED_REALLIFE", requested.get("mode").asText());
        assertEquals("iPhone", requested.get("challengeCategory").asText(), "nur vom Handy gemessene Challenges");
    }

    @Test
    void knowledgeLeagueDoesNotRevealTheFirstQuestion() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        attacker.send(createMode("RANKED_KNOWLEDGE"));
        JsonNode requested = defender.await("battle-requested", 5);
        assertNotNull(requested);
        assertEquals("RANKED_KNOWLEDGE", requested.get("mode").asText());
        assertTrue(requested.get("challengeText").asText().startsWith("Quiz-Show"));
    }

    @Test
    void quizShowWithFourQuestionsAndSpeedPoints() throws Exception {
        GameSocket.quizIntro = Duration.ofMillis(50);
        GameSocket.quizRevealPause = Duration.ofMillis(50);
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        int knowledgeBefore = trophies(A);
        long battleId = createAcceptedRanked(attacker, defender, "RANKED_KNOWLEDGE");

        for (int round = 1; round <= 4; round++) {
            JsonNode qa = attacker.await("quiz-question", 5);
            JsonNode qb = defender.await("quiz-question", 5);
            assertNotNull(qa, "Frage " + round);
            assertNotNull(qb);
            assertEquals(round, qa.get("round").asInt());
            assertEquals(4, qa.get("rounds").asInt());
            assertFalse(qa.get("question").has("correctIndex"), "Antwort nicht mitschicken");
            int correct = correctIndexFor(qa.get("question").get("id").asLong());
            attacker.send(quizAnswer(battleId, round, correct));            // A immer richtig
            defender.send(quizAnswer(battleId, round, (correct + 1) % 4));  // B immer falsch
            JsonNode reveal = attacker.await("quiz-round-result", 5);
            assertNotNull(reveal);
            assertEquals(correct, reveal.get("correctIndex").asInt());
            assertTrue(reveal.get("answers").get(A).get("points").asInt() >= 100);
            assertEquals(0, reveal.get("answers").get(B).get("points").asInt());
            defender.await("quiz-round-result", 5);
        }

        JsonNode result = attacker.await("battle-result", 5);
        assertNotNull(result, "Nach 4 Fragen kommt das Ergebnis");
        assertEquals(A, result.get("winnerId").asText());
        assertEquals("RANKED_KNOWLEDGE", result.get("mode").asText());
        assertTrue(result.get("quiz").get("fromScore").asInt() >= 400);
        assertEquals(0, result.get("quiz").get("toScore").asInt());
        assertTrue(trophies(A) > knowledgeBefore, "Liga-Trophäen steigen (gemeinsamer Stand)");
    }

    @Test
    void quizRoundClosesWhenNobodyAnswers() throws Exception {
        GameSocket.quizIntro = Duration.ofMillis(50);
        GameSocket.quizRevealPause = Duration.ofMillis(50);
        GameSocket.quizRoundTime = Duration.ofMillis(200);
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        createAcceptedRanked(attacker, defender, "RANKED_KNOWLEDGE");
        JsonNode result = attacker.await("battle-result", 20);
        assertNotNull(result, "Quiz endet auch ohne Antworten");
        assertEquals("DRAW", result.get("outcome").asText());
    }

    @Test
    void quizPointsRewardSpeed() {
        assertEquals(150, GameSocket.quizPoints(true, 0, 15000));
        assertEquals(125, GameSocket.quizPoints(true, 7500, 15000));
        assertEquals(100, GameSocket.quizPoints(true, 20000, 15000));
        assertEquals(0, GameSocket.quizPoints(false, 100, 15000));
    }

    @Test
    void battleIsOnlyEvaluatedOnce() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        int before = points(B);

        long battleId = createAcceptedBattle(attacker, defender);

        // Beide geben gleichzeitig auf + Doppelklick
        attacker.send(status(battleId, "DONE_SURRENDER"));
        defender.send(status(battleId, "DONE_SURRENDER"));
        attacker.send(status(battleId, "DONE_SURRENDER"));

        JsonNode first = attacker.await("battle-result", 5);
        assertNotNull(first);
        Thread.sleep(1000);
        assertTrue(attacker.all("battle-result").isEmpty(), "Nur ein Ergebnis pro Battle");

        // Punkte genau einmal verbucht (egal wer gewonnen hat)
        int after = points(B);
        String winner = first.get("winnerId").asText();
        int expectedDelta = winner.equals(B) ? first.get("winnerPointsDelta").asInt() : first.get("loserPointsDelta").asInt();
        assertEquals(before + expectedDelta, after);
    }

    // ------------------------------------------------------------ Mess-Challenges

    @Test
    void sprintWaitsForBothResults() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        long battleId = createAcceptedBattle(attacker, defender);

        attacker.send("{\"type\":\"sprint-result\",\"battleId\":" + battleId + ",\"distance\":5.0}");
        assertNotNull(attacker.await("battle-pending", 5), "Wer zuerst fertig ist, wartet");
        assertNull(defender.await("battle-result", 1), "Nach dem ersten Ergebnis wird noch nicht ausgewertet");

        defender.send("{\"type\":\"sprint-result\",\"battleId\":" + battleId + ",\"distance\":12.5}");
        JsonNode result = attacker.await("battle-result", 5);
        assertNotNull(result);
        assertEquals(B, result.get("winnerId").asText(), "Der Weitere gewinnt, nicht der Schnellere beim Senden");
        assertEquals(12.5, result.at("/metrics/sprint/winner").asDouble(), 0.001);
        assertEquals(5.0, result.at("/metrics/sprint/loser").asDouble(), 0.001);
    }

    @Test
    void missingOpponentLosesAfterTimeout() throws Exception {
        GameSocket.resultWait = Duration.ofMillis(500);
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        long battleId = createAcceptedBattle(attacker, defender);
        attacker.send("{\"type\":\"compass-result\",\"battleId\":" + battleId + ",\"distance\":90.0}");

        JsonNode result = defender.await("battle-result", 5);
        assertNotNull(result, "Nach dem Timeout wird ausgewertet");
        assertEquals(A, result.get("winnerId").asText(), "Wer nichts schickt, verliert");
        assertTrue(result.path("metrics").isMissingNode(), "Ohne zweiten Wert keine Vergleichswerte");
    }

    @Test
    void equalShakesAreADrawWithoutPoints() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        int beforeA = points(A);
        int beforeB = points(B);

        long battleId = createAcceptedBattle(attacker, defender);
        attacker.send("{\"type\":\"shake-result\",\"battleId\":" + battleId + ",\"shakes\":30}");
        defender.send("{\"type\":\"shake-result\",\"battleId\":" + battleId + ",\"shakes\":30}");

        JsonNode result = attacker.await("battle-result", 5);
        assertNotNull(result);
        assertTrue(result.get("winnerId").isNull());
        assertEquals("Unentschieden!", result.get("trashTalk").asText());
        assertEquals(beforeA, points(A));
        assertEquals(beforeB, points(B));
    }

    @Test
    void resultsForFinishedBattleAreIgnored() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        long battleId = createAcceptedBattle(attacker, defender);
        attacker.send(status(battleId, "DONE_SURRENDER"));
        assertNotNull(attacker.await("battle-result", 5));

        attacker.send("{\"type\":\"pushup-result\",\"battleId\":" + battleId + ",\"reps\":50}");
        defender.send("{\"type\":\"pushup-result\",\"battleId\":" + battleId + ",\"reps\":10}");
        assertNull(attacker.await("battle-result", 1), "Fertiges Battle wird nicht nochmal ausgewertet");
    }

    // ------------------------------------------------------------------ Voting

    @Test
    void votesByIdAndDoubleVoteIgnored() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        long battleId = createAcceptedBattle(attacker, defender);
        String vote = "{\"type\":\"battle-vote\",\"battleId\":" + battleId + ",\"winnerId\":\"" + A + "\"}";

        attacker.send(vote);
        attacker.send(vote); // doppelt
        assertNull(attacker.await("battle-result", 1), "Ein Spieler allein entscheidet nicht");

        defender.send(vote);
        JsonNode result = attacker.await("battle-result", 5);
        assertNotNull(result);
        assertEquals(A, result.get("winnerId").asText());
    }

    @Test
    void bystanderCannotVote() throws Exception {
        WsTestClient attacker  = connect(A);
        WsTestClient defender  = connect(B);
        WsTestClient bystander = connect(BYSTANDER);

        long battleId = createAcceptedBattle(attacker, defender);
        bystander.send("{\"type\":\"battle-vote\",\"battleId\":" + battleId + ",\"winnerId\":\"" + A + "\"}");
        attacker.send("{\"type\":\"battle-vote\",\"battleId\":" + battleId + ",\"winnerId\":\"" + A + "\"}");

        assertNull(attacker.await("battle-result", 1), "Stimme eines Unbeteiligten zählt nicht");
    }

    @Test
    void differentVotesAreAConflict() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        int conflictsBefore = QuarkusTransaction.requiringNew().call(
                () -> playerRepository.findById(A).getConsecutiveConflicts());

        long battleId = createAcceptedBattle(attacker, defender);
        attacker.send("{\"type\":\"battle-vote\",\"battleId\":" + battleId + ",\"winnerId\":\"" + A + "\"}");
        defender.send("{\"type\":\"battle-vote\",\"battleId\":" + battleId + ",\"winnerId\":\"" + B + "\"}");

        JsonNode result = attacker.await("battle-result", 5);
        assertNotNull(result);
        assertTrue(result.get("winnerId").isNull());
        assertEquals("Niemand", result.get("winnerName").asText());
        assertEquals(conflictsBefore + 1, (int) QuarkusTransaction.requiringNew().call(
                () -> playerRepository.findById(A).getConsecutiveConflicts()));
    }

    // ------------------------------------------------------------------ Wissen

    @Test
    void knowledgeQuestionDoesNotRevealTheAnswer() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        createAcceptedBattle(attacker, defender, wissenChallengeId());

        JsonNode question = defender.await("battle-question", 5);
        assertNotNull(question);
        assertEquals(4, question.at("/challenge/choices").size());
        assertTrue(question.at("/challenge/correctIndex").isMissingNode(), "Richtige Antwort darf nicht mitkommen");
    }

    @Test
    void wrongAnswerContinuesRightAnswerWins() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        long challengeId = wissenChallengeId();
        int correct = challengeRepository.findById(challengeId).getCorrectIndex();
        int wrong = (correct + 1) % 4;

        long battleId = createAcceptedBattle(attacker, defender, challengeId);

        attacker.send("{\"type\":\"battle-answer\",\"battleId\":" + battleId + ",\"answerIndex\":" + wrong + "}");
        assertNull(attacker.await("battle-result", 1), "Falsche Antwort beendet das Battle nicht");

        defender.send("{\"type\":\"battle-answer\",\"battleId\":" + battleId + ",\"answerIndex\":" + correct + "}");
        JsonNode result = attacker.await("battle-result", 5);
        assertNotNull(result);
        assertEquals(B, result.get("winnerId").asText());
    }

    private static String answer(long battleId, int index) {
        return "{\"type\":\"battle-answer\",\"battleId\":" + battleId + ",\"answerIndex\":" + index + "}";
    }

    @Test
    void bothWrongAnswersEndInADraw() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        long challengeId = wissenChallengeId();
        int correct = challengeRepository.findById(challengeId).getCorrectIndex();
        int before = points(A);

        long battleId = createAcceptedBattle(attacker, defender, challengeId);

        attacker.send(answer(battleId, (correct + 1) % 4));
        JsonNode feedback = attacker.await("battle-answer-feedback", 5);
        assertNotNull(feedback, "Spieler erfährt, dass seine Antwort falsch war");
        assertFalse(feedback.get("correct").asBoolean());

        defender.send(answer(battleId, (correct + 2) % 4));
        JsonNode result = defender.await("battle-result", 5);
        assertNotNull(result, "Beide falsch → das Battle endet trotzdem");
        assertTrue(result.get("winnerId").isNull(), "Unentschieden: kein Gewinner");
        assertEquals("DRAW", result.get("outcome").asText());
        assertEquals(0, result.get("winnerPointsDelta").asInt());
        assertNotNull(attacker.await("battle-result", 5));
        assertEquals(before, points(A), "Unentschieden ändert keine Punkte");
    }

    @Test
    void onlyTheFirstAnswerCounts() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        long challengeId = wissenChallengeId();
        int correct = challengeRepository.findById(challengeId).getCorrectIndex();

        long battleId = createAcceptedBattle(attacker, defender, challengeId);

        // Durchprobieren: erst falsch, dann richtig
        attacker.send(answer(battleId, (correct + 1) % 4));
        assertNotNull(attacker.await("battle-answer-feedback", 5));
        attacker.send(answer(battleId, correct));
        assertNull(attacker.await("battle-result", 1), "Zweite Antwort desselben Spielers wird ignoriert");

        defender.send(answer(battleId, correct));
        JsonNode result = attacker.await("battle-result", 5);
        assertNotNull(result);
        assertEquals(B, result.get("winnerId").asText());
    }

    @Test
    void knowledgeBattleEndsAfterTimeLimit() throws Exception {
        GameSocket.knowledgeTimeLimit = Duration.ofSeconds(1);
        try {
            WsTestClient attacker = connect(A);
            WsTestClient defender = connect(B);

            createAcceptedBattle(attacker, defender, wissenChallengeId());
            JsonNode question = defender.await("battle-question", 5);
            assertEquals(1, question.get("timeLimitSeconds").asInt(), "App bekommt das Zeitlimit für den Countdown");

            // Niemand antwortet
            JsonNode result = attacker.await("battle-result", 8);
            assertNotNull(result, "Nach dem Zeitlimit gibt es ein Ergebnis");
            assertTrue(result.get("winnerId").isNull());
        } finally {
            GameSocket.knowledgeTimeLimit = GameSocket.DEFAULT_KNOWLEDGE_TIME_LIMIT;
        }
    }

    // --------------------------------------------------- Anfragen / Status

    @Test
    void playerInABattleCannotBeChallenged() throws Exception {
        WsTestClient attacker  = connect(A);
        WsTestClient defender  = connect(B);
        WsTestClient third     = connect(BYSTANDER);

        long battleId = createAcceptedBattle(attacker, defender);

        // Dritter fordert den Verteidiger mitten im Battle heraus
        third.send("{\"type\":\"create-battle\",\"fromId\":\"" + BYSTANDER + "\",\"toId\":\"" + B + "\",\"challengeId\":1}");
        JsonNode rejected = third.await("battle-rejected", 5);
        assertNotNull(rejected, "Anfrage an einen Spieler im Battle wird abgelehnt");
        assertTrue(rejected.get("reason").asText().contains("Battle"));
        assertNull(defender.await("battle-requested", 1), "Verteidiger wird nicht gestört");

        // Das laufende Battle lässt sich normal beenden
        attacker.send(status(battleId, "DONE_SURRENDER"));
        JsonNode result = defender.await("battle-result", 5);
        assertNotNull(result);
        assertEquals(B, result.get("winnerId").asText());

        // Danach ist der Verteidiger wieder herausforderbar
        third.send("{\"type\":\"create-battle\",\"fromId\":\"" + BYSTANDER + "\",\"toId\":\"" + B + "\",\"challengeId\":1}");
        assertNotNull(defender.await("battle-requested", 5));
    }

    @Test
    void playerInABattleCannotChallengeOthers() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        connect(BYSTANDER);

        createAcceptedBattle(attacker, defender);

        attacker.send("{\"type\":\"create-battle\",\"fromId\":\"" + A + "\",\"toId\":\"" + BYSTANDER + "\",\"challengeId\":1}");
        assertNotNull(attacker.await("battle-rejected", 5));
    }

    @Test
    void runningBattleIsRestoredAfterReconnect() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        long battleId = createAcceptedBattle(attacker, defender);

        // Verteidiger beendet die App mitten im Battle und startet neu
        defender.close();
        WsTestClient restarted = connect(B);
        JsonNode running = restarted.await("battle-running", 5);
        assertNotNull(running, "Laufendes Battle wird nach dem Neustart gemeldet");
        assertEquals(battleId, running.get("battleId").asLong());
        assertEquals(A, running.get("fromPlayerId").asText());

        // Aufgeben nach dem Neustart beendet das Battle ganz normal
        restarted.send(status(battleId, "DONE_SURRENDER"));
        JsonNode result = attacker.await("battle-result", 5);
        assertNotNull(result);
        assertEquals(A, result.get("winnerId").asText());
    }

    @Test
    void knowledgeQuestionIsResentAfterReconnect() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        createAcceptedBattle(attacker, defender, wissenChallengeId());
        assertNotNull(defender.await("battle-question", 5));

        defender.close();
        WsTestClient restarted = connect(B);
        assertNotNull(restarted.await("battle-running", 5));
        assertNotNull(restarted.await("battle-question", 5), "Frage kommt nach dem Neustart erneut");
    }

    @Test
    void ownOpenRequestIsRestoredAfterReconnect() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        long battleId = request(attacker, defender, 1L);

        // Angreifer startet die App neu
        attacker.close();
        WsTestClient restarted = connect(A);
        JsonNode restored = restarted.await("battle-requested", 5);
        assertNotNull(restored, "Eigene offene Anfrage wird nach dem Neustart nachgeliefert");
        assertEquals(battleId, restored.get("battleId").asLong());
        assertEquals(A, restored.get("fromPlayerId").asText());

        // Annahme erreicht die neue Verbindung
        defender.send(status(battleId, "ACCEPTED"));
        assertNotNull(restarted.awaitStatus("ACCEPTED", 5), "Annahme kommt nach dem Neustart an");
    }

    private void setCharacter(String playerId, String character) {
        QuarkusTransaction.requiringNew().run(() -> playerRepository.findById(playerId).setCharacter(character));
    }

    @Test
    void battlePayloadsCarryNamesAndCharacters() throws Exception {
        setCharacter(A, "ragnar");
        setCharacter(B, "sir-brecht");
        try {
            WsTestClient attacker = connect(A);
            WsTestClient defender = connect(B);
            attacker.send(create(1L));
            JsonNode requested = defender.await("battle-requested", 5);
            assertNotNull(requested);
            assertEquals("ragnar", requested.get("fromCharacter").asText());
            assertEquals("sir-brecht", requested.get("toCharacter").asText());
            assertFalse(requested.get("fromName").asText().isEmpty(), "Name des Herausforderers fehlt");
        } finally {
            setCharacter(A, null);
            setCharacter(B, null);
        }
    }

    @Test
    void restoredBattleKnowsWhetherResultWasAlreadySent() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        long battleId = createAcceptedBattle(attacker, defender);
        attacker.send(status(battleId, "READY_FOR_VOTING"));
        assertNotNull(defender.awaitStatus("READY_FOR_VOTING", 5));

        // Verteidiger stimmt ab und startet dann neu
        defender.send("{\"type\":\"battle-vote\",\"battleId\":" + battleId + ",\"winnerId\":\"" + B + "\"}");
        Thread.sleep(300);
        defender.close();
        JsonNode running = connect(B).await("battle-running", 5);
        assertNotNull(running);
        assertTrue(running.get("submitted").asBoolean(), "Stimme ist schon abgegeben → Ergebnis abwarten");

        // Angreifer hat noch nicht abgestimmt
        attacker.close();
        JsonNode runningA = connect(A).await("battle-running", 5);
        assertNotNull(runningA);
        assertFalse(runningA.get("submitted").asBoolean());
    }

    @Test
    void conflictResultNamesBothPlayers() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        long battleId = createAcceptedBattle(attacker, defender);
        attacker.send("{\"type\":\"battle-vote\",\"battleId\":" + battleId + ",\"winnerId\":\"" + A + "\"}");
        defender.send("{\"type\":\"battle-vote\",\"battleId\":" + battleId + ",\"winnerId\":\"" + B + "\"}");

        JsonNode result = attacker.await("battle-result", 5);
        assertNotNull(result);
        assertEquals("CONFLICT", result.get("outcome").asText());
        assertEquals(A, result.get("fromId").asText());
        assertEquals(B, result.get("toId").asText());
        assertNotEquals("Niemand", result.get("fromName").asText());
        assertNotEquals("Niemand", result.get("toName").asText());
    }

    private static String emote(String to, String emoji, Long battleId) {
        return "{\"type\":\"send-emote\",\"toId\":\"" + to + "\",\"emoji\":\"" + emoji + "\""
                + (battleId == null ? "" : ",\"battleId\":" + battleId) + "}";
    }

    @Test
    void emotesReachTheOpponentOnly() throws Exception {
        GameSocket.resetEmoteCooldowns();
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        long battleId = createAcceptedBattle(attacker, defender);

        attacker.send(emote(B, "🔥", battleId));
        JsonNode got = defender.await("emote", 5);
        assertNotNull(got, "Gegner bekommt das Emote");
        assertEquals("🔥", got.get("emoji").asText());
        assertEquals(A, got.get("fromId").asText());
        assertEquals(battleId, got.get("battleId").asLong());
    }

    @Test
    void unknownEmojiAndSpamAreIgnored() throws Exception {
        GameSocket.resetEmoteCooldowns();
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        attacker.send(emote(B, "du bist doof", null));
        assertNull(defender.await("emote", 1), "Freitext wird nicht weitergeleitet");

        attacker.send(emote(B, "👋", null));
        assertNotNull(defender.await("emote", 3), "Emote auf der Karte kommt an");
        attacker.send(emote(B, "👋", null));
        assertNull(defender.await("emote", 1), "zweites Emote sofort danach wird gedrosselt");
    }

    @Test
    void cancelledRequestCannotBeAccepted() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        long battleId = request(attacker, defender, 1L);
        attacker.send(status(battleId, "CANCELLED"));
        assertNotNull(defender.awaitStatus("CANCELLED", 5), "Empfänger erfährt vom Abbruch");

        defender.send(status(battleId, "ACCEPTED"));
        assertNotNull(defender.awaitStatus("CANCELLED", 5), "Annehmen wird mit aktuellem Status beantwortet");
        assertNull(attacker.awaitStatus("ACCEPTED", 1));
    }

    @Test
    void surrenderBeforeAcceptIsIgnored() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        long battleId = request(attacker, defender, 1L);
        attacker.send(status(battleId, "DONE_SURRENDER"));

        assertNull(defender.await("battle-result", 1), "Nicht angenommenes Battle kann nicht beendet werden");
    }

    @Test
    void pendingRequestIsDeliveredAfterReconnect() throws Exception {
        WsTestClient attacker = connect(A);

        attacker.send(create(1L));
        assertNotNull(attacker.await("battle-created", 5));

        // Empfänger kommt erst jetzt online
        WsTestClient defender = connect(B);
        JsonNode requested = defender.await("battle-requested", 5);
        assertNotNull(requested, "Offene Anfrage wird nachgeliefert");
        assertTrue(requested.get("expiresInSeconds").asInt() > 0);
    }

    @Test
    void expiryJobInformsBothPlayers() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        long battleId = request(attacker, defender, 1L);
        QuarkusTransaction.requiringNew().run(() -> battleRepository.findById(battleId)
                .setCreatedAt(LocalDateTime.now().minusMinutes(5)));

        expiryJob.expireStaleRequests();

        assertNotNull(attacker.awaitStatus("EXPIRED", 5));
        assertNotNull(defender.awaitStatus("EXPIRED", 5));
    }

    @Test
    void stuckBattleIsAbandonedWithoutPoints() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);
        int beforeA = points(A);

        long battleId = createAcceptedBattle(attacker, defender);
        QuarkusTransaction.requiringNew().run(() -> battleRepository.findById(battleId)
                .setStatusChangedAt(LocalDateTime.now().minusMinutes(30)));

        expiryJob.abandonStaleBattles();

        assertNotNull(attacker.awaitStatus("ABANDONED", 5));
        assertNotNull(defender.awaitStatus("ABANDONED", 5));

        // Späteres Aufgeben ändert nichts mehr
        defender.send(status(battleId, "DONE_SURRENDER"));
        assertNull(attacker.await("battle-result", 1));
        assertEquals(beforeA, points(A));
    }

    @Test
    void invalidRequestsAreRejected() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        attacker.send("{\"type\":\"create-battle\",\"fromId\":\"" + A + "\",\"toId\":\"" + A + "\",\"challengeId\":1}");
        assertNotNull(attacker.await("battle-rejected", 5), "Sich selbst herausfordern");

        attacker.send("{\"type\":\"create-battle\",\"fromId\":\"" + B + "\",\"toId\":\"" + BYSTANDER + "\",\"challengeId\":1}");
        assertNotNull(attacker.await("battle-rejected", 5), "Im Namen eines anderen herausfordern");

        request(attacker, defender, 1L);
        attacker.send(create(1L));
        JsonNode rejected = attacker.await("battle-rejected", 5);
        assertNotNull(rejected, "Zweite offene Anfrage an denselben Spieler");
        assertFalse(rejected.get("reason").asText().isBlank());
    }

    @Test
    void messagesWithSpacesAreUnderstood() throws Exception {
        WsTestClient attacker = connect(A);
        WsTestClient defender = connect(B);

        // Früher scheiterte die Erkennung an Leerzeichen nach dem Doppelpunkt
        attacker.send("{ \"type\": \"create-battle\", \"fromId\": \"" + A + "\", \"toId\": \"" + B + "\", \"challengeId\": 1 }");
        assertNotNull(defender.await("battle-requested", 5));
    }

    @Test
    void brokenMessagesGetAnErrorInsteadOfCrashing() throws Exception {
        WsTestClient attacker = connect(A);

        attacker.send("das ist kein json");
        assertNotNull(attacker.await("error", 5));

        attacker.send("{\"type\":\"gibts-nicht\"}");
        assertNotNull(attacker.await("error", 5));

        attacker.send("{\"type\":\"create-battle\",\"fromId\":\"" + A + "\"}");
        assertNotNull(attacker.await("battle-rejected", 5), "Fehlende Felder → Ablehnung statt Absturz");
    }

    // --------------------------------------------------------------- Positionen

    @Test
    void positionUpdatesOnlyReachNearbyPlayersWithoutCoordinates() throws Exception {
        QuarkusTransaction.requiringNew().run(() -> {
            if (playerRepository.findById("far-away") == null) {
                Player far = new Player("Weitweg", 13.0, 47.0); // ~150 km entfernt
                far.setId("far-away");
                playerRepository.createPlayer(far);
            }
        });

        WsTestClient nearby = connect(B);
        WsTestClient far    = connect("far-away");

        Login.as(A)
                .contentType("application/json")
                .body("{\"id\":\"" + A + "\",\"name\":\"EigenerSpieler\",\"latitude\":48.268340,\"longitude\":14.251390,\"points\":0}")
                .when().put("/api/players/" + A)
                .then().statusCode(200);

        JsonNode event = nearby.await("player-position-updated", 5);
        assertNotNull(event, "Spieler in der Nähe wird informiert");
        assertEquals(A, event.get("playerId").asText());
        assertTrue(event.path("latitude").isMissingNode() && event.path("longitude").isMissingNode(),
                "Keine genauen Koordinaten im Event");

        assertNull(far.await("player-position-updated", 1), "Weit entfernte Spieler bekommen nichts");
    }
}
