package boundary;

import control.HotspotCatalog;
import control.LandmarkRules;
import control.LandmarkService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.hamcrest.Matchers.*;

/** Orte aus OpenStreetMap als Check-in-Punkte: sichtbar in der Nähe, Einchecken mit Tageslimit. */
@QuarkusTest
class LandmarkHotspotTest {

    @Inject
    LandmarkService landmarks;

    /** Irgendwo weit weg von der Schule, eigener Fleck pro Test */
    private double baseLat(int i) { return 47.0 + i * 0.1 + (System.nanoTime() % 1000) / 1_000_000.0; }

    private String newPlayerAt(double lat, double lon) {
        String id = "lm-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":" + lat + ",\"longitude\":" + lon + "}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    private static String checkinBody(String id, double lat, double lon) {
        return "{\"playerId\":\"" + id + "\",\"latitude\":" + lat + ",\"longitude\":" + lon + "}";
    }

    @Test
    void landmarksNearThePlayerCanBeCheckedInWithADailyLimit() {
        double lat = baseLat(1), lon = 13.0;
        // 7 Orte in einer Reihe, je 300 m auseinander
        List<LandmarkRules.Candidate> c = new ArrayList<>();
        long seed = System.nanoTime();
        for (int i = 0; i < 7; i++) {
            c.add(new LandmarkRules.Candidate("osm-n-" + (seed + i), "Brunnen " + i, lat + i * 0.0027, lon, "fountain", 45));
        }
        landmarks.store(LandmarkRules.tileKey(lat, lon) + "t" + seed % 1000, c);

        String me = newPlayerAt(lat, lon);
        Login.as(me).when().get("/api/hotspots").then().statusCode(200)
                .body("find { it.id == 'osm-n-" + seed + "' }.kind", is("landmark"))
                .body("find { it.id == 'osm-n-" + seed + "' }.category", is("fountain"))
                .body("find { it.id == 'osm-n-" + seed + "' }.points", is(HotspotCatalog.LANDMARK_POINTS))
                .body("find { it.id == 'htl-leonding' }.kind", is("school"));

        // zu weit weg
        Login.as(me).contentType("application/json").body(checkinBody(me, lat + 0.01, lon))
                .when().post("/api/hotspots/osm-n-" + seed + "/checkin").then().statusCode(403);

        // 5 Orte gehen, der 6. nicht mehr (Tageslimit)
        for (int i = 0; i < HotspotCatalog.LANDMARK_DAILY_LIMIT; i++) {
            Login.as(me).contentType("application/json").body(checkinBody(me, lat + i * 0.0027, lon))
                    .when().post("/api/hotspots/osm-n-" + (seed + i) + "/checkin").then().statusCode(200)
                    .body("points", is(HotspotCatalog.LANDMARK_POINTS + HotspotCatalog.LANDMARK_FIRST_OF_DAY_BONUS));
        }
        int last = HotspotCatalog.LANDMARK_DAILY_LIMIT;
        Login.as(me).contentType("application/json").body(checkinBody(me, lat + last * 0.0027, lon))
                .when().post("/api/hotspots/osm-n-" + (seed + last) + "/checkin").then().statusCode(429);
        // doppelt am selben Ort
        Login.as(me).contentType("application/json").body(checkinBody(me, lat, lon))
                .when().post("/api/hotspots/osm-n-" + seed + "/checkin").then().statusCode(anyOf(is(409), is(429)));
    }

    @Test
    void landmarksFarAwayAreNotListed() {
        double lat = baseLat(5), lon = 15.5;
        long seed = System.nanoTime();
        landmarks.store("far" + seed % 100000, List.of(new LandmarkRules.Candidate("osm-n-" + seed, "Ferner Park", lat + 0.05, lon, "park", 80)));
        String me = newPlayerAt(lat, lon);
        Login.as(me).when().get("/api/hotspots").then().statusCode(200).body("id", not(hasItem("osm-n-" + seed)));
    }
}
