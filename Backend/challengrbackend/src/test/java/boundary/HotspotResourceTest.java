package boundary;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Hotspot an der Schule: einmal am Tag einchecken, Erster des Tages bekommt Bonus. */
@QuarkusTest
class HotspotResourceTest {

    private static final double LAT = 48.26832, LON = 14.25138;

    private String newPlayer(String prefix) {
        String id = prefix + "-" + System.nanoTime();
        given().contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":" + LAT + ",\"longitude\":" + LON + "}")
                .when().post("/api/players").then().statusCode(anyOf(is(200), is(204)));
        return id;
    }

    private io.restassured.response.Response checkin(String player, double lat, double lon) {
        return given().contentType("application/json")
                .body("{\"playerId\":\"" + player + "\",\"latitude\":" + lat + ",\"longitude\":" + lon + "}")
                .when().post("/api/hotspots/htl-leonding/checkin");
    }

    @Test
    void checkinOncePerDayInsideRadius() {
        String a = newPlayer("hs-a");
        int before = given().when().get("/api/players/" + a).then().extract().path("points");

        // zu weit weg (ca. 1 km)
        checkin(a, LAT + 0.01, LON).then().statusCode(403);

        var first = checkin(a, LAT + 0.0002, LON).then().statusCode(200).extract();
        int points = first.path("points");
        boolean firstOfDay = first.path("firstOfDay");
        assertEquals(firstOfDay ? 25 : 10, points);
        assertEquals(before + points, (int) first.path("totalPoints"));

        // nochmal am selben Tag
        checkin(a, LAT, LON).then().statusCode(409);

        given().when().get("/api/hotspots?playerId=" + a).then().statusCode(200)
                .body("find { it.id == 'htl-leonding' }.checkedInToday", is(true));

        // zweiter Spieler ist sicher nicht mehr der Erste
        String b = newPlayer("hs-b");
        checkin(b, LAT, LON).then().statusCode(200)
                .body("firstOfDay", is(false))
                .body("points", is(10));
    }

    @Test
    void unknownHotspotOrPlayer() {
        given().contentType("application/json").body("{\"playerId\":\"x\",\"latitude\":1,\"longitude\":1}")
                .when().post("/api/hotspots/mond/checkin").then().statusCode(404);
        checkin("gibts-nicht-" + System.nanoTime(), LAT, LON).then().statusCode(404);
    }
}
