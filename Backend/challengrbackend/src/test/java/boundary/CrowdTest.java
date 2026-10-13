package boundary;

import control.PlayerRepository;
import entity.Player;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/** Schulhof-Szenario: 200 Spieler auf einem Fleck – nearby bleibt klein und schnell. */
@QuarkusTest
class CrowdTest {

    private static final double LAT = 45.90000, LON = 13.90000; // abseits der anderen Tests

    @Inject
    PlayerRepository playerRepository;

    @Test
    void twoHundredPlayersOnOneSpot() {
        String run = Long.toString(System.nanoTime(), 36);
        QuarkusTransaction.requiringNew().run(() -> {
            for (int i = 0; i < 200; i++) {
                Player p = new Player("crowd" + i, LON + (i % 20) * 0.00005, LAT + (i / 20) * 0.00005);
                p.setId("crowd-" + run + "-" + i);
                p.setLastSeenAt(Instant.now());
                playerRepository.createPlayer(p);
            }
        });
        String me = "crowd-" + run + "-0";

        long start = System.nanoTime();
        var response = Login.as(me).when().get("/api/players/nearby?radius=300").then().statusCode(200).extract();
        long ms = (System.nanoTime() - start) / 1_000_000;

        List<String> ids = response.jsonPath().getList("id");
        assertEquals(PlayerRessources.MAX_NEARBY_RESULTS, ids.size(), "nur die nächsten auf die Karte");
        assertEquals("199", response.header(PlayerRessources.NEARBY_TOTAL_HEADER), "Gesamtzahl für die Anzeige");
        assertTrue(ms < 2000, "Antwortzeit " + ms + " ms");
        System.out.println("nearby mit 200 Spielern: " + ms + " ms");
    }

    @Test
    void positionEventsAreThrottledPerPlayer() {
        GameSocket.resetPositionThrottle();
        assertTrue(GameSocket.mayAnnouncePosition("crowd-throttle"));
        assertFalse(GameSocket.mayAnnouncePosition("crowd-throttle"), "zweites Event innerhalb von 5 s gedrosselt");
        assertTrue(GameSocket.mayAnnouncePosition("crowd-other"), "andere Spieler unabhängig");
    }
}
