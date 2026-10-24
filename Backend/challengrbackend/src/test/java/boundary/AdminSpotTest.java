package boundary;

import control.LandmarkRules;
import control.LandmarkService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.util.List;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/** Orte ausblenden, eigene Orte, Auswertungen und Ankündigungen. */
@QuarkusTest
class AdminSpotTest {

    @Inject
    LandmarkService landmarks;

    private String playerAt(double lat, double lon) {
        String id = "spot-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":" + lat + ",\"longitude\":" + lon + "}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    @Test
    void hiddenLandmarkDisappearsAndCanComeBack() {
        double lat = 46.5 + (System.nanoTime() % 1000) / 100_000.0, lon = 13.0;
        String osm = "osm-n-" + System.nanoTime();
        landmarks.store("hide" + System.nanoTime() % 100000, List.of(new LandmarkRules.Candidate(osm, "Friedhofspark", lat, lon, "park", 80)));
        String p = playerAt(lat, lon);
        Login.as(p).when().get("/api/hotspots").then().body("id", hasItem(osm));

        Login.admin().contentType("application/json").body("{\"reason\":\"unpassend\"}")
                .when().post("/api/admin/spots/landmarks/" + osm + "/hide").then().statusCode(204);
        Login.as(p).when().get("/api/hotspots").then().body("id", not(hasItem(osm)));
        Login.as(p).contentType("application/json").body("{\"playerId\":\"" + p + "\",\"latitude\":" + lat + ",\"longitude\":" + lon + "}")
                .when().post("/api/hotspots/" + osm + "/checkin").then().statusCode(404);
        Login.admin().when().get("/api/admin/spots/landmarks?hidden=true").then().body("id", hasItem(osm));

        Login.admin().when().delete("/api/admin/spots/landmarks/" + osm + "/hide").then().statusCode(204);
        Login.as(p).when().get("/api/hotspots").then().body("id", hasItem(osm));
    }

    @Test
    void customSpotIsVisibleToEveryoneAndCheckable() {
        double lat = 47.8 + (System.nanoTime() % 1000) / 100_000.0, lon = 13.04;
        String id = Login.admin().contentType("application/json")
                .body("{\"name\":\"Andere Schule\",\"latitude\":" + lat + ",\"longitude\":" + lon + ",\"radiusMeters\":60,\"points\":10,\"bonus\":15}")
                .when().post("/api/admin/spots/custom").then().statusCode(200).extract().path("id");
        Login.admin().contentType("application/json").body("{\"name\":\"x\",\"latitude\":1,\"longitude\":2}")
                .when().post("/api/admin/spots/custom").then().statusCode(400);

        String p = playerAt(48.3, 14.3);   // weit weg – eigene Orte sieht trotzdem jeder
        Login.as(p).when().get("/api/hotspots").then().body("find { it.id == '" + id + "' }.kind", is("custom"));
        String near = playerAt(lat, lon);
        Login.as(near).contentType("application/json").body("{\"playerId\":\"" + near + "\",\"latitude\":" + lat + ",\"longitude\":" + lon + "}")
                .when().post("/api/hotspots/" + id + "/checkin").then().statusCode(200).body("points", is(25));

        Login.admin().when().get("/api/admin/spots/popular").then().statusCode(200)
                .body("find { it.id == '" + id + "' }.checkins", is(1)).body("find { it.id == '" + id + "' }.kind", is("Eigener Ort"));
        Login.admin().when().delete("/api/admin/spots/custom/" + id).then().statusCode(204);
        Login.as(p).when().get("/api/hotspots").then().body("id", not(hasItem(id)));
    }

    @Test
    void heatmapOnlyShowsCellsWithSeveralPlayers() {
        double lat = 45.1234, lon = 12.3456;
        for (int i = 0; i < 3; i++) playerAt(lat + i * 0.0001, lon);
        playerAt(44.0, 11.0);   // allein → nicht sichtbar
        List<java.util.Map<String, Object>> cells = Login.admin().when().get("/api/admin/spots/heatmap").then().statusCode(200)
                .body("minPlayersPerCell", is(3)).extract().jsonPath().getList("cells");
        org.junit.jupiter.api.Assertions.assertTrue(cells.stream().anyMatch(c ->
                Math.abs(((Number) c.get("latitude")).doubleValue() - 45.125) < 0.003 && ((Number) c.get("players")).intValue() >= 3));
        org.junit.jupiter.api.Assertions.assertTrue(cells.stream().noneMatch(c ->
                Math.abs(((Number) c.get("latitude")).doubleValue() - 44.0) < 0.003), "einzelner Spieler bleibt unsichtbar");
    }

    @Test
    void announcementShowsInAppUntilEnded() {
        String p = playerAt(48.3, 14.3);
        long id = ((Number) Login.admin().contentType("application/json").body("{\"text\":\"Halloween-Event startet morgen!\"}")
                .when().post("/api/admin/announcements").then().statusCode(200).body("showing", is(true)).extract().path("id")).longValue();
        Login.as(p).when().get("/api/announcement").then().statusCode(200).body("text", is("Halloween-Event startet morgen!"));
        given().when().get("/api/announcement").then().statusCode(401);
        Login.as(p).contentType("application/json").body("{\"text\":\"hack\"}").when().post("/api/admin/announcements").then().statusCode(403);
        Login.admin().when().delete("/api/admin/announcements/" + id).then().statusCode(204);
        Login.as(p).when().get("/api/announcement").then().statusCode(204);
        Login.admin().contentType("application/json").body("{\"text\":\"Später\",\"startsAt\":\"2099-01-01T00:00:00Z\"}")
                .when().post("/api/admin/announcements").then().statusCode(200).body("showing", is(false));
        Login.as(p).when().get("/api/announcement").then().statusCode(204);
    }
}
