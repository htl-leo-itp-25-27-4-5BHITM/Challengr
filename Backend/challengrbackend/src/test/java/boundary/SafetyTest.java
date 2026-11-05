package boundary;

import control.NameFilter;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import java.util.List;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** B2: Melden und Blockieren – der Server setzt die Blockierung überall durch. */
@QuarkusTest
class SafetyTest {

    @jakarta.inject.Inject
    BattleService battleService;

    private String newPlayer(String prefix, double lat, double lon) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":" + lat + ",\"longitude\":" + lon + "}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    @Test
    void blockingHidesBothPlayersFromEachOther() {
        String a = newPlayer("blk-a", 46.50000, 14.20000);
        String b = newPlayer("blk-b", 46.50010, 14.20010);
        Login.as(a).when().get("/api/players/nearby?radius=300").then().body("id", hasItem(b));

        Login.as(a).when().post("/api/safety/blocks/" + b).then().statusCode(204);

        Login.as(a).when().get("/api/players/nearby?radius=300").then().body("id", not(hasItem(b)));
        Login.as(b).when().get("/api/players/nearby?radius=300").then().body("id", not(hasItem(a)));
        Login.as(a).when().get("/api/safety/blocks").then().statusCode(200).body("id", hasItem(b));

        // Herausforderung B → A wird vom Server abgelehnt
        assertThrows(BattleRejectedException.class, () -> battleService.createRequestedBattle(b, a, 1L, control.BattleMode.FRIENDLY));

        // Freundschaftsanfrage B → A wird abgelehnt
        Login.as(b).contentType("application/json").body("{\"fromPlayerId\":\"" + b + "\",\"toPlayerId\":\"" + a + "\"}")
                .when().post("/api/friends/requests").then().statusCode(403);

        // Wieder freigeben
        Login.as(a).when().delete("/api/safety/blocks/" + b).then().statusCode(204);
        Login.as(a).when().get("/api/players/nearby?radius=300").then().body("id", hasItem(b));
    }

    @Test
    void reportsShowUpForAdminsOnly() {
        String a = newPlayer("rep-a", 46.4, 14.1);
        String b = newPlayer("rep-b", 46.4, 14.1);

        Login.as(a).contentType("application/json").body("{\"reason\":\"BELEIDIGUNG\",\"comment\":\"hat mich beschimpft\"}")
                .when().post("/api/safety/reports/" + b).then().statusCode(204);
        // doppelt melden erzeugt keine zweite offene Meldung
        Login.as(a).contentType("application/json").body("{\"reason\":\"BELEIDIGUNG\"}")
                .when().post("/api/safety/reports/" + b).then().statusCode(204);
        Login.as(a).contentType("application/json").body("{\"reason\":\"QUATSCH\"}")
                .when().post("/api/safety/reports/" + b).then().statusCode(400);

        Login.as(a).when().get("/api/admin/reports").then().statusCode(403);
        List<Integer> ids = Login.admin().when().get("/api/admin/reports").then().statusCode(200)
                .extract().jsonPath().getList("findAll { it.reportedId == '" + b + "' }.id");
        assertEquals(1, ids.size());

        Login.admin().contentType("application/json").when().post("/api/admin/reports/" + ids.get(0) + "/resolve")
                .then().statusCode(200).body("status", is("RESOLVED"));
    }

    @Test
    void offensiveNamesAreReplacedOrRejected() {
        String id = "name-" + System.nanoTime();
        Login.as(id).contentType("application/json").body("{\"id\":\"" + id + "\",\"name\":\"Fuck3r\"}")
                .when().post("/api/players").then().statusCode(200).body("name", startsWith("Spieler-"));
        // Umbenennen geht über /name (Standort-Updates ändern den Namen nicht)
        Login.as(id).contentType("application/json").body("{\"name\":\"Hurens0hn\"}")
                .when().put("/api/players/" + id + "/name").then().statusCode(400);
        Login.as(id).contentType("application/json").body("{\"name\":\"Marschall\"}")
                .when().put("/api/players/" + id + "/name").then().statusCode(anyOf(is(200), is(409)));
    }

    @Test
    void nameFilterAvoidsFalseAlarms() {
        for (String ok : List.of("Marschall", "Heilmann", "Benedikt", "Essex", "Basti", "Mia_07", "Scunthorpe Fan")) {
            assertFalse(NameFilter.isOffensive(ok), ok);
        }
        for (String bad : List.of("F.u.c.k", "Arsch", "xxHitlerxx", "Hure", "b1tch", "Nazi Boy")) {
            assertTrue(NameFilter.isOffensive(bad), bad);
        }
    }
}
