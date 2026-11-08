package boundary;

import com.fasterxml.jackson.databind.JsonNode;
import control.BattleRepository;
import control.ChaosService;
import control.PlayerRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.common.http.TestHTTPResource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Chaos-Stunde: Zeitfenster pro Tag und die Regeln im Spiel. */
@QuarkusTest
class ChaosTest {

    private static final String A = "demo-1";
    private static final String B = "demo-2";

    @TestHTTPResource("/ws/game")
    URI wsUri;

    @Inject
    BattleRepository battles;

    @Inject
    PlayerRepository players;

    private final List<WsTestClient> clients = new ArrayList<>();

    @BeforeEach
    void clean() {
        QuarkusTransaction.requiringNew().run(() -> battles.update(
                "status = 'EXPIRED' where status not in ('DONE','EXPIRED','CANCELLED','DECLINED','ABANDONED')"));
    }

    @AfterEach
    void reset() throws Exception {
        ChaosService.override = null;
        for (WsTestClient c : clients) c.close();
    }

    @Test
    void oneHourPerDayBetweenTwoAndEightPm() {
        EnumSet<ChaosService.Rule> seen = EnumSet.noneOf(ChaosService.Rule.class);
        LocalDate day = LocalDate.of(2026, 11, 1);
        for (int i = 0; i < 120; i++, day = day.plusDays(1)) {
            var w = ChaosService.windowFor(day);
            LocalTime start = w.start().atZone(control.ActivityTracker.ZONE).toLocalTime();
            LocalTime end = w.end().atZone(control.ActivityTracker.ZONE).toLocalTime();
            assertFalse(start.isBefore(LocalTime.of(14, 0)), day + " " + start);
            assertFalse(end.isAfter(LocalTime.of(20, 0)), day + " " + end);
            assertEquals(w, ChaosService.windowFor(day), "gleicher Tag = gleiche Chaos-Stunde");
            seen.add(w.rule());
        }
        assertEquals(EnumSet.allOf(ChaosService.Rule.class), seen, "alle Regeln kommen vor");
    }

    @Test
    void endpointShowsTheRunningRule() {
        ChaosService.override = ChaosService.Rule.GIANTS;
        Login.as(A).when().get("/api/chaos").then().statusCode(200)
                .body("active", is(true))
                .body("rule", is("GIANTS"))
                .body("title", is("Riesen-Stunde"));
    }

    @Test
    void megaQuizHasSixQuestionsAndScreamOnlyPicksTheScream() throws Exception {
        WsTestClient a = WsTestClient.connect(wsUri, A); clients.add(a);
        WsTestClient b = WsTestClient.connect(wsUri, B); clients.add(b);

        ChaosService.override = ChaosService.Rule.MEGA_QUIZ;
        a.send("{\"type\":\"create-battle\",\"toId\":\"" + B + "\",\"mode\":\"RANKED_KNOWLEDGE\"}");
        JsonNode quiz = b.await("battle-requested", 5);
        assertNotNull(quiz);
        assertEquals("Quiz-Show: 6 Fragen", quiz.get("challengeText").asText());
        a.send("{\"type\":\"update-battle-status\",\"battleId\":" + quiz.get("battleId").asLong() + ",\"status\":\"CANCELLED\"}");

        ChaosService.override = ChaosService.Rule.SCREAM_ONLY;
        for (int i = 0; i < 4; i++) {
            QuarkusTransaction.requiringNew().run(() -> battles.update(
                    "status = 'EXPIRED' where status not in ('DONE','EXPIRED','CANCELLED','DECLINED','ABANDONED')"));
            a.send("{\"type\":\"create-battle\",\"toId\":\"" + B + "\",\"mode\":\"RANKED_REALLIFE\"}");
            JsonNode real = b.await("battle-requested", 5);
            assertNotNull(real);
            assertTrue(real.get("challengeText").asText().startsWith("Schrei-Challenge"), real.get("challengeText").asText());
        }
    }

    @Test
    void doubleTrophiesForTheWinner() throws Exception {
        WsTestClient a = WsTestClient.connect(wsUri, A); clients.add(a);
        WsTestClient b = WsTestClient.connect(wsUri, B); clients.add(b);
        ChaosService.override = ChaosService.Rule.DOUBLE_TROPHIES;
        int aTrophies = QuarkusTransaction.requiringNew().call(() -> players.findById(A).getTrophies());
        int bTrophies = QuarkusTransaction.requiringNew().call(() -> players.findById(B).getTrophies());
        var normal = control.TrophyMath.delta(bTrophies, aTrophies);

        a.send("{\"type\":\"create-battle\",\"toId\":\"" + B + "\",\"mode\":\"RANKED_REALLIFE\"}");
        JsonNode req = b.await("battle-requested", 5);
        long id = req.get("battleId").asLong();
        b.send("{\"type\":\"update-battle-status\",\"battleId\":" + id + ",\"status\":\"ACCEPTED\"}");
        assertNotNull(a.awaitStatus("ACCEPTED", 5));
        a.send("{\"type\":\"update-battle-status\",\"battleId\":" + id + ",\"status\":\"DONE_SURRENDER\"}");
        JsonNode result = b.await("battle-result", 5);
        assertNotNull(result);
        int bonus = result.has("bountyBonus") ? result.get("bountyBonus").asInt() : 0;
        assertEquals(normal.winnerDelta() * 2 + bonus, result.get("winnerPointsDelta").asInt());
        assertEquals(normal.loserDelta(), result.get("loserPointsDelta").asInt());
    }
}
