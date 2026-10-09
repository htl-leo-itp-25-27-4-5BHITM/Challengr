package boundary;

import control.PlayerRepository;
import entity.Player;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Abnahme der TestFlight-Checkliste (docs/audit/TESTFLIGHT_SECURITY_CHECKLIST.md):
 * A2 Login + eigene Daten, A3 Admin-Endpoints, A5 Standortschutz.
 */
@QuarkusTest
class SecurityChecklistTest {

    private static final double LAT = 47.5, LON = 13.5; // abseits der Demo-Spieler

    @Inject
    PlayerRepository playerRepository;

    private String newPlayer(String prefix, double lat, double lon) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":" + lat + ",\"longitude\":" + lon + "}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    private void setPoints(String id, int points) {
        QuarkusTransaction.requiringNew().run(() -> playerRepository.findById(id).setPoints(points));
    }

    private int points(String id) {
        return QuarkusTransaction.requiringNew().call(() -> playerRepository.findById(id).getPoints());
    }

    // ------------------------------------------------------------------ A2

    @Test
    void withoutLoginEverythingPersonalIs401() {
        String a = newPlayer("a2-anon", LAT, LON);
        given().contentType("application/json").body("{\"name\":\"x\",\"latitude\":1,\"longitude\":1}")
                .when().put("/api/players/" + a).then().statusCode(401);
        given().when().get("/api/players/nearby?radius=200").then().statusCode(401);
        given().when().get("/api/friends/list?playerId=" + a).then().statusCode(401);
        given().contentType("application/json").body("{\"itemCode\":\"x\"}")
                .when().post("/api/shop/players/" + a + "/purchase").then().statusCode(401);
        // bewusst öffentlich: Stammdaten
        given().when().get("/api/ranks").then().statusCode(200);
        given().when().get("/api/challenges/categories").then().statusCode(200);
        given().when().get("/api/shop/items").then().statusCode(200);
    }

    @Test
    void foreignAccountsCannotBeChanged() {
        String a = newPlayer("a2-a", LAT, LON);
        String b = newPlayer("a2-b", LAT, LON);

        Login.as(a).contentType("application/json").body("{\"name\":\"gehackt\",\"latitude\":1,\"longitude\":1}")
                .when().put("/api/players/" + b).then().statusCode(403);
        Login.as(a).contentType("application/json").body("{\"status\":\"x\",\"badges\":[]}")
                .when().put("/api/players/" + b + "/profile").then().statusCode(403);
        Login.as(a).contentType("application/json").body("{\"character\":\"junge\"}")
                .when().put("/api/players/" + b + "/character").then().statusCode(403);
        Login.as(a).contentType("application/json").body("{\"id\":\"" + b + "\",\"name\":\"x\"}")
                .when().post("/api/players").then().statusCode(403);
        Login.as(a).when().get("/api/friends/gifts/incoming?playerId=" + b).then().statusCode(403);
        Login.as(a).contentType("application/json").when().post("/api/friends/gifts/1/claim?playerId=" + b).then().statusCode(403);

        // eigenes Konto geht
        Login.as(a).contentType("application/json").body("{\"name\":\"" + a + "\",\"latitude\":" + LAT + ",\"longitude\":" + LON + "}")
                .when().put("/api/players/" + a).then().statusCode(200);
    }

    @Test
    void shoppingForSomeoneElseIsForbiddenAndCostsNothing() {
        String a = newPlayer("a2-shop-a", LAT, LON);
        String b = newPlayer("a2-shop-b", LAT, LON);
        setPoints(b, 5000);
        String item = given().when().get("/api/shop/items").then().statusCode(200).extract().path("[0].code");

        Login.as(a).contentType("application/json").body("{\"itemCode\":\"" + item + "\"}")
                .when().post("/api/shop/players/" + b + "/purchase").then().statusCode(403);
        assertEquals(5000, points(b), "Münzstand von B bleibt gleich");

        setPoints(a, 5000);
        Login.as(a).contentType("application/json").body("{\"itemCode\":\"" + item + "\"}")
                .when().post("/api/shop/players/" + a + "/purchase").then().statusCode(200);
        assertTrue(points(a) < 5000, "eigener Kauf funktioniert");
    }

    @Test
    void createIgnoresPointsAndBansFromTheClient() {
        String id = "a2-cheat-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"x\",\"points\":999999,\"trophies\":99999,\"latitude\":1,\"longitude\":1}")
                .when().post("/api/players").then().statusCode(200)
                .body("points", is(200)).body("trophies", is(200));
    }

    // ------------------------------------------------------------------ A3

    @Test
    void adminEndpointsNeedTheAdminRole() {
        String victim = newPlayer("a3-victim", LAT, LON);
        String ban = "{\"durationSeconds\":3600,\"reason\":\"test\"}";

        given().contentType("application/json").body(ban).when().post("/api/admin/players/" + victim + "/ban").then().statusCode(401);
        Login.as(victim).contentType("application/json").body(ban).when().post("/api/admin/players/" + victim + "/ban").then().statusCode(403);
        given().when().get("/api/admin/erd").then().statusCode(401);
        Login.as(victim).when().get("/api/admin/erd").then().statusCode(403);
        Login.as(victim).when().get("/api/admin/erd/table/player").then().statusCode(403);

        Login.admin().when().get("/api/admin/erd").then().statusCode(200);
    }

    // ------------------------------------------------------------------ A5

    @Test
    void nearbyIsLimitedToTheOwnSurroundingsWithRoundedCoordinates() {
        String me = newPlayer("a5-me", 46.60000, 14.30000);
        String close = newPlayer("a5-close", 46.60031, 14.30017);   // ~38 m
        String far = newPlayer("a5-far", 46.62000, 14.30000);       // ~2,2 km

        // riesiger Radius und fremder Mittelpunkt werden ignoriert
        List<Map<String, Object>> list = Login.as(me)
                .when().get("/api/players/nearby?playerId=" + far + "&latitude=46.62&longitude=14.3&radius=100000")
                .then().statusCode(200).extract().jsonPath().getList("$");

        assertTrue(list.stream().anyMatch(p -> close.equals(p.get("id"))), "Spieler in 300 m sichtbar");
        assertTrue(list.stream().noneMatch(p -> far.equals(p.get("id"))), "Spieler in 2 km nicht sichtbar");
        Map<String, Object> c = list.stream().filter(p -> close.equals(p.get("id"))).findFirst().orElseThrow();
        double lat = ((Number) c.get("latitude")).doubleValue();
        double lon = ((Number) c.get("longitude")).doubleValue();
        assertEquals(Math.round(lat * 2000), lat * 2000, 0.02, "auf 0.0005° gerundet (JSON als float gelesen)");
        assertEquals(Math.round(lon * 2000), lon * 2000, 0.02, "auf 0.0005° gerundet (JSON als float gelesen)");
        assertNotEquals(46.60031, lat, 1e-7, "nicht metergenau");
        assertNotEquals(14.30017, lon, 1e-7);
    }

    @Test
    void invisibleAndInactivePlayersDoNotShowUp() {
        String me = newPlayer("a5-me2", 46.70000, 14.40000);
        String hidden = newPlayer("a5-hidden", 46.70010, 14.40010);
        String gone = newPlayer("a5-gone", 46.70020, 14.40020);

        Login.as(hidden).contentType("application/json").body("{\"invisible\":true}")
                .when().put("/api/players/" + hidden + "/visibility").then().statusCode(200).body("invisible", is(true));
        Login.as(me).contentType("application/json").body("{\"invisible\":true}")
                .when().put("/api/players/" + hidden + "/visibility").then().statusCode(403);
        QuarkusTransaction.requiringNew().run(() ->
                playerRepository.findById(gone).setLastSeenAt(Instant.now().minus(Duration.ofMinutes(6))));

        List<String> ids = Login.as(me).when().get("/api/players/nearby?radius=300")
                .then().statusCode(200).extract().jsonPath().getList("id");
        assertFalse(ids.contains(hidden), "unsichtbar");
        assertFalse(ids.contains(gone), "seit über 5 Minuten inaktiv");
    }

    @Test
    void foreignProfilesHaveNoCoordinates() {
        String a = newPlayer("a5-prof-a", 46.8, 14.5);
        String b = newPlayer("a5-prof-b", 46.8, 14.5);
        Login.as(a).when().get("/api/players/" + b).then().statusCode(200)
                .body("latitude", nullValue()).body("longitude", nullValue());
        Login.as(b).when().get("/api/players/" + b).then().statusCode(200)
                .body("latitude", notNullValue());
    }
}
