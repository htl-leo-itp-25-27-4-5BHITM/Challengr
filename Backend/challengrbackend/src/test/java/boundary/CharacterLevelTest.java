package boundary;

import com.fasterxml.jackson.databind.JsonNode;
import control.BattleRepository;
import control.CharacterLevel;
import control.PlayerRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.common.http.TestHTTPResource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.util.ArrayList;
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Figuren-Stufen: Liga-Siege mit einer Figur bringen sie nach oben. */
@QuarkusTest
class CharacterLevelTest {

    @TestHTTPResource("/ws/game")
    URI wsUri;

    @Inject
    EntityManager em;

    @Inject
    BattleRepository battles;

    @Inject
    PlayerRepository players;

    private final List<WsTestClient> clients = new ArrayList<>();

    @AfterEach
    void close() throws Exception {
        for (WsTestClient c : clients) c.close();
    }

    @Test
    void levelThresholds() {
        assertEquals(1, CharacterLevel.level(0));
        assertEquals(2, CharacterLevel.level(1));
        assertEquals(3, CharacterLevel.level(3));
        assertEquals(3, CharacterLevel.level(5));
        assertEquals(6, CharacterLevel.level(15));
        assertEquals(10, CharacterLevel.level(45));
        assertEquals(10, CharacterLevel.level(500));
        assertEquals(3, CharacterLevel.nextLevelWins(2));
        assertEquals(-1, CharacterLevel.nextLevelWins(10));
    }

    private String newPlayer(String prefix) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":48.3,\"longitude\":14.3}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    /** loser fordert winner in der Liga heraus und gibt auf → winner gewinnt */
    private JsonNode leagueWin(String winner, String loser) throws Exception {
        QuarkusTransaction.requiringNew().run(() -> battles.update(
                "status = 'EXPIRED' where status not in ('DONE','EXPIRED','CANCELLED','DECLINED','ABANDONED')"));
        WsTestClient l = WsTestClient.connect(wsUri, loser); clients.add(l);
        WsTestClient w = WsTestClient.connect(wsUri, winner); clients.add(w);
        l.send("{\"type\":\"create-battle\",\"toId\":\"" + winner + "\",\"mode\":\"RANKED_REALLIFE\"}");
        JsonNode req = w.await("battle-requested", 5);
        long id = req.get("battleId").asLong();
        w.send("{\"type\":\"update-battle-status\",\"battleId\":" + id + ",\"status\":\"ACCEPTED\"}");
        assertNotNull(l.awaitStatus("ACCEPTED", 5));
        l.send("{\"type\":\"update-battle-status\",\"battleId\":" + id + ",\"status\":\"DONE_SURRENDER\"}");
        JsonNode result = w.await("battle-result", 5);
        assertNotNull(result);
        l.close(); w.close();
        return result;
    }

    @Test
    void leagueWinsRaiseTheLevelOfTheChosenCharacter() throws Exception {
        String me = newPlayer("lvl-me"), other = newPlayer("lvl-other");
        JsonNode first = leagueWin(me, other);
        assertEquals(2, first.get("winnerLevelUp").asInt(), "erster Sieg: Stufe 2");
        JsonNode second = leagueWin(me, other);
        assertFalse(second.has("winnerLevelUp"), "zweiter Sieg: noch Stufe 2");
        leagueWin(me, other);

        Login.as(me).when().get("/api/players/" + me + "/characters").then().statusCode(200)
                .body("find { it.id == 'junge' }.level", is(3))
                .body("find { it.id == 'junge' }.levelWins", is(3))
                .body("find { it.id == 'junge' }.nextLevelWins", is(6))
                .body("find { it.id == 'maedchen' }.level", is(1));
        Login.as(me).when().get("/api/players/" + me).then().statusCode(200).body("characterLevel", is(3));

        // Figur wechseln: Stufe der neuen Figur
        Login.as(me).contentType("application/json").body("{\"character\":\"maedchen\"}")
                .when().put("/api/players/" + me + "/character").then().statusCode(200).body("characterLevel", is(1));
    }
}
