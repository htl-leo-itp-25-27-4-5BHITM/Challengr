package boundary;

import com.fasterxml.jackson.databind.JsonNode;
import control.BattleRepository;
import control.ChallengeRepository;
import control.PlayerRepository;
import control.PracticeBot;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.common.http.TestHTTPResource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Übungsmodus: der Trainings-Dummy nimmt an, spielt mit – und nichts davon zählt. */
@QuarkusTest
class PracticeBotTest {

    private static final String A = "demo-1";
    private static final String B = "demo-2";

    @TestHTTPResource("/ws/game")
    URI wsUri;

    @Inject
    BattleRepository battleRepository;

    @Inject
    ChallengeRepository challengeRepository;

    @Inject
    PlayerRepository playerRepository;

    private final List<WsTestClient> clients = new ArrayList<>();

    private WsTestClient connect(String playerId) throws Exception {
        WsTestClient client = WsTestClient.connect(wsUri, playerId);
        clients.add(client);
        return client;
    }

    @BeforeEach
    void fast() {
        GameSocket.botAcceptDelay = Duration.ofMillis(100);
        GameSocket.botMetricDelay = Duration.ofMillis(100);
        GameSocket.quizIntro = Duration.ofMillis(50);
        GameSocket.quizRevealPause = Duration.ofMillis(50);
        GameSocket.quizRoundTime = Duration.ofMillis(600);
        GameSocket.resetEmoteCooldowns();
        QuarkusTransaction.requiringNew().run(() -> battleRepository.update(
                "status = 'EXPIRED' where status not in ('DONE','EXPIRED','CANCELLED','DECLINED','ABANDONED')"));
    }

    @AfterEach
    void reset() throws Exception {
        GameSocket.quizIntro = GameSocket.DEFAULT_QUIZ_INTRO;
        GameSocket.quizRevealPause = GameSocket.DEFAULT_QUIZ_REVEAL;
        GameSocket.quizRoundTime = GameSocket.DEFAULT_QUIZ_ROUND_TIME;
        for (WsTestClient c : clients) c.close();
    }

    private static String practice(String mode) {
        return "{\"type\":\"create-battle\",\"toId\":\"" + PracticeBot.ID + "\",\"mode\":\"" + mode + "\"}";
    }

    private long startPractice(WsTestClient me, String mode) throws Exception {
        me.send(practice(mode));
        JsonNode requested = me.await("battle-requested", 5);
        assertNotNull(requested, "eigene Anfrage kommt zurück");
        assertEquals(PracticeBot.NAME, requested.get("toName").asText());
        assertEquals(PracticeBot.CHARACTER, requested.get("toCharacter").asText());
        assertNotNull(me.awaitStatus("ACCEPTED", 5), "der Bot nimmt von selbst an");
        return requested.get("battleId").asLong();
    }

    private int trophies(String id) {
        return QuarkusTransaction.requiringNew().call(() -> playerRepository.findById(id).getTrophies());
    }

    private int correctIndexFor(long challengeId) {
        return QuarkusTransaction.requiringNew().call(() -> challengeRepository.findById(challengeId).getCorrectIndex());
    }

    @Test
    void quizShowAgainstTheBotCountsNowhere() throws Exception {
        WsTestClient me = connect(A);
        int before = trophies(A);
        long battleId = startPractice(me, "RANKED_KNOWLEDGE");

        boolean botAnswered = false;
        for (int round = 1; round <= 4; round++) {
            JsonNode q = me.await("quiz-question", 5);
            assertNotNull(q, "Frage " + round);
            int correct = correctIndexFor(q.get("question").get("id").asLong());
            me.send("{\"type\":\"quiz-answer\",\"battleId\":" + battleId + ",\"round\":" + round + ",\"answerIndex\":" + correct + "}");
            JsonNode reveal = me.await("quiz-round-result", 5);
            assertNotNull(reveal);
            botAnswered |= reveal.at("/answers/" + PracticeBot.ID + "/answerIndex").asInt(-1) >= 0;
        }
        assertTrue(botAnswered, "der Bot antwortet in der Quiz-Show");

        JsonNode result = me.await("battle-result", 5);
        assertNotNull(result);
        assertEquals(0, result.get("winnerPointsDelta").asInt());
        assertEquals(0, result.get("loserPointsDelta").asInt());
        assertTrue(result.get("winnerSticker").isNull(), "kein Sieger-Sticker im Training");
        assertEquals(before, trophies(A), "Trophäen bleiben gleich");

        Login.as(A).when().get("/api/players/" + A + "/battles").then().statusCode(200)
                .body("id", not(hasItem((int) battleId)));
    }

    /** Übungs-Quiz-Show zu Ende spielen, immer falsch antworten → 0 Punkte */
    private JsonNode loseQuizOnPurpose(WsTestClient me) throws Exception {
        long battleId = startPractice(me, "RANKED_KNOWLEDGE");
        for (int round = 1; round <= 4; round++) {
            JsonNode q = me.await("quiz-question", 5);
            assertNotNull(q, "Frage " + round);
            int wrong = (correctIndexFor(q.get("question").get("id").asLong()) + 1) % 4;
            me.send("{\"type\":\"quiz-answer\",\"battleId\":" + battleId + ",\"round\":" + round + ",\"answerIndex\":" + wrong + "}");
            assertNotNull(me.await("quiz-round-result", 5));
        }
        JsonNode result = me.await("battle-result", 5);
        assertNotNull(result);
        return result;
    }

    @Test
    void glitchBreaksOutAfterThreeZeroPointQuizShows() throws Exception {
        String id = "glitch-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":48.3,\"longitude\":14.3}")
                .when().post("/api/players").then().statusCode(200);
        WsTestClient me = connect(id);
        assertFalse(loseQuizOnPurpose(me).has("secretUnlocked"));
        assertFalse(loseQuizOnPurpose(me).has("secretUnlocked"));
        Login.as(id).when().get("/api/players/" + id + "/characters").then().statusCode(200)
                .body("find { it.id == 'glitch' }.unlocked", is(false));
        JsonNode third = loseQuizOnPurpose(me);
        assertEquals("glitch", third.get("secretUnlocked").asText(), "Glitch bricht aus dem Dummy aus");
        Login.as(id).when().get("/api/players/" + id + "/characters").then().statusCode(200)
                .body("find { it.id == 'glitch' }.unlocked", is(true));
    }

    @Test
    void realLifeAgainstTheBotWithTwoPlayersAtOnce() throws Exception {
        WsTestClient me = connect(A);
        WsTestClient other = connect(B);
        long mine = startPractice(me, "RANKED_REALLIFE");
        long theirs = startPractice(other, "RANKED_REALLIFE");
        assertNotEquals(mine, theirs, "der Bot spielt mit beiden gleichzeitig");

        me.send("{\"type\":\"reaction-result\",\"battleId\":" + mine + ",\"ms\":320}");
        JsonNode result = me.await("battle-result", 5);
        assertNotNull(result, "der Bot liefert seinen Wert nach");
        assertTrue(result.has("metrics") || "DRAW".equals(result.get("outcome").asText()));
        assertEquals(0, result.get("winnerPointsDelta").asInt());
    }

    @Test
    void practicePoolHasNoCheckInSpot() throws Exception {
        WsTestClient me = connect(A);
        for (int i = 0; i < 8; i++) {
            me.send(practice("RANKED_REALLIFE"));
            JsonNode requested = me.await("battle-requested", 5);
            assertNotNull(requested);
            assertFalse(requested.get("challengeText").asText().contains("Check-In-Spot"));
            assertNotNull(me.awaitStatus("ACCEPTED", 5));
            me.send("{\"type\":\"update-battle-status\",\"battleId\":" + requested.get("battleId").asLong()
                    + ",\"status\":\"DONE_SURRENDER\"}");
            assertNotNull(me.await("battle-result", 5));
        }
    }

    @Test
    void friendlyAgainstTheBotIsRejected() throws Exception {
        WsTestClient me = connect(A);
        me.send("{\"type\":\"create-battle\",\"toId\":\"" + PracticeBot.ID + "\",\"challengeId\":1}");
        assertNotNull(me.await("battle-rejected", 5));
    }

    @Test
    void botRepliesToEmotesInTheBattle() throws Exception {
        WsTestClient me = connect(A);
        long battleId = startPractice(me, "RANKED_REALLIFE");
        me.send("{\"type\":\"send-emote\",\"toId\":\"" + PracticeBot.ID + "\",\"emoji\":\"🔥\",\"battleId\":" + battleId + "}");
        JsonNode reply = me.await("emote", 5);
        assertNotNull(reply);
        assertEquals(PracticeBot.ID, reply.get("fromId").asText());
        assertTrue(GameSocket.EMOTES.containsAll(PracticeBot.REPLIES));
    }

    @Test
    void botIsNotListedAnywhere() throws Exception {
        WsTestClient me = connect(A);
        startPractice(me, "RANKED_REALLIFE"); // legt den Bot an
        Login.as(A).when().get("/api/leaderboard").then().statusCode(200)
                .body("school.playerId", not(hasItem(PracticeBot.ID)));
        Login.as(A).when().get("/api/players/search?q=dummy").then().statusCode(200)
                .body("id", not(hasItem(PracticeBot.ID)));
    }

    @Test
    void botPlaysFairlyButNotPerfectly() {
        Random random = new Random(7);
        int correct = 0;
        for (int i = 0; i < 1000; i++) {
            var move = PracticeBot.quizMove(2, 15000, random);
            assertTrue(move.answerIndex() >= 0 && move.answerIndex() < 4);
            assertTrue(move.delayMs() >= 3750 && move.delayMs() <= 11250);
            if (move.answerIndex() == 2) correct++;
        }
        assertTrue(correct > 450 && correct < 650, "etwa jede zweite Antwort richtig: " + correct);

        int better = 0;
        for (int i = 0; i < 1000; i++) {
            double v = PracticeBot.metricValue(20, true, random);
            assertTrue(v >= 15 && v <= 25 && v == Math.rint(v));
            if (v > 20) better++;
        }
        assertTrue(better > 300 && better < 600, "mal besser, mal schlechter: " + better);
        assertTrue(PracticeBot.metricValue(0, false, random) >= 0, "nie negativ");
        assertTrue(PracticeBot.metricValue(-30, false, random) < 0, "Lautstärke in dB darf negativ bleiben");
    }
}
