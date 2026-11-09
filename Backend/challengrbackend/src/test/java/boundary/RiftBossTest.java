package boundary;

import com.fasterxml.jackson.databind.JsonNode;
import control.PlayerRepository;
import control.RiftBossService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.common.http.TestHTTPResource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Riss-Wächter: nur zu zweit zu schaffen, Raserei mit Riss-Schlag, Finale gemeinsam schreien. */
@QuarkusTest
class RiftBossTest {

    private static final String A = "demo-1";
    private static final String B = "demo-2";
    private static final double LAT = 48.2685, LON = 14.2515;

    @TestHTTPResource("/ws/game")
    URI wsUri;

    @Inject
    RiftBossService bosses;

    @Inject
    PlayerRepository players;

    private final List<WsTestClient> clients = new ArrayList<>();

    private void place(String id, double lat, double lon) {
        QuarkusTransaction.requiringNew().run(() -> {
            var p = players.findById(id);
            p.setLatitude(lat);
            p.setLongitude(lon);
        });
    }

    private int shards(String id) {
        return QuarkusTransaction.requiringNew().call(() -> players.findById(id).getRiftShards());
    }

    private WsTestClient connect(String id) throws Exception {
        WsTestClient c = WsTestClient.connect(wsUri, id);
        clients.add(c);
        return c;
    }

    private static String join(long boss) {
        return "{\"type\":\"boss-join\",\"bossId\":" + boss + "}";
    }

    @BeforeEach
    void setUp() {
        bosses.clear();
        place(A, LAT, LON);
        place(B, LAT + 0.0005, LON);
    }

    @AfterEach
    void tearDown() throws Exception {
        RiftBossService.fightTime = Duration.ofMinutes(3);
        for (WsTestClient c : clients) c.close();
        bosses.clear();
    }

    @Test
    void visibleNearbyAndSpawnableByAdmin() {
        Login.admin().contentType("application/json")
                .body("{\"place\":\"Hauptplatz\",\"latitude\":" + LAT + ",\"longitude\":" + LON + "}")
                .when().post("/api/bosses/spawn").then().statusCode(200).body("phase", is("WAITING"));
        Login.as(A).contentType("application/json")
                .body("{\"place\":\"X\",\"latitude\":1,\"longitude\":1}")
                .when().post("/api/bosses/spawn").then().statusCode(403);
        Login.as(A).when().get("/api/bosses/nearby").then().statusCode(200)
                .body("bosses.place", hasItem("Hauptplatz"))
                .body("bosses[0].maxHp", is(RiftBossService.MAX_HP))
                .body("bosses[0].minFighters", is(2));
    }

    @Test
    void dashboardOpensARiftNearAPlayerAndClosesIt() {
        QuarkusTransaction.requiringNew().run(() -> players.findById(A).setLastSeenAt(Instant.now()));
        Login.admin().when().get("/api/admin/bosses/players").then().statusCode(200)
                .body("id", hasItem(A))
                .body("find { it.id == 'demo-1' }.name", notNullValue());
        Login.as(A).when().get("/api/admin/bosses/players").then().statusCode(403);

        int id = Login.admin().contentType("application/json").body("{\"playerId\":\"" + A + "\"}")
                .when().post("/api/admin/bosses/spawn").then().statusCode(200)
                .body("phase", is("WAITING"))
                .extract().path("id");
        Login.as(A).when().get("/api/bosses/nearby").then().statusCode(200).body("bosses.id", hasItem(id));
        Login.admin().when().get("/api/admin/bosses").then().statusCode(200).body("id", hasItem(id));

        Login.admin().when().delete("/api/admin/bosses/" + id).then().statusCode(204);
        Login.as(A).when().get("/api/bosses/nearby").then().statusCode(200).body("bosses.id", not(hasItem(id)));
        Login.admin().when().delete("/api/admin/bosses/" + id).then().statusCode(404);
        Login.admin().contentType("application/json").body("{\"playerId\":\"gibts-nicht\"}")
                .when().post("/api/admin/bosses/spawn").then().statusCode(404);
    }

    @Test
    void aloneTheFightDoesNotEvenStart() throws Exception {
        long id = bosses.spawn("Park", LAT, LON).id;
        WsTestClient a = connect(A);
        a.send(join(id));
        JsonNode state = a.await("boss-state", 5);
        assertEquals("WAITING", state.get("phase").asText());
        assertEquals(1, state.get("fighters").asInt());
        a.send("{\"type\":\"boss-hit\",\"bossId\":" + id + ",\"units\":10}");
        Thread.sleep(300);
        assertEquals(RiftBossService.MAX_HP, bosses.find(id).orElseThrow().hp(), "allein kein Schaden");
    }

    @Test
    void tooFarAwayIsRejected() throws Exception {
        long id = bosses.spawn("Park", LAT + 0.05, LON).id;
        WsTestClient a = connect(A);
        a.send(join(id));
        JsonNode rejected = a.await("boss-rejected", 5);
        assertNotNull(rejected);
        assertTrue(rejected.get("reason").asText().contains("zu weit"));
    }

    @Test
    void soloDamageCannotOutpaceTheHealing() {
        // Höchstschaden eines Spielers pro Sekunde abzüglich Heilung über die ganze Kampfzeit < Lebenspunkte
        long seconds = RiftBossService.fightTime.toSeconds();
        assertTrue((RiftBossService.MAX_DPS - RiftBossService.HEAL_PER_SECOND) * seconds < RiftBossService.MAX_HP);
    }

    @Test
    void twoPlayersRageSlamFinaleAndVictory() throws Exception {
        long id = bosses.spawn("Brunnen", LAT, LON).id;
        int shardsA = shards(A), shardsB = shards(B);
        WsTestClient a = connect(A), b = connect(B);
        a.send(join(id));
        a.await("boss-state", 5);
        b.send(join(id));
        JsonNode fight = b.awaitMatching("boss-state", n -> "FIGHT".equals(n.get("phase").asText()), 5);
        assertNotNull(fight, "der zweite Kämpfer startet den Kampf");

        a.send("{\"type\":\"boss-hit\",\"bossId\":" + id + ",\"units\":5}");
        JsonNode hit = a.awaitMatching("boss-state", n -> n.get("hp").asInt() < RiftBossService.MAX_HP, 5);
        assertEquals(RiftBossService.MAX_HP - 5 * RiftBossService.DAMAGE_PER_UNIT, hit.get("hp").asInt());

        // Raserei ab 50 %
        bosses.setHp(id, RiftBossService.MAX_HP / 2);
        assertEquals("RAGE", a.await("boss-phase", 5).get("phase").asText());
        bosses.tick(Instant.now().plusSeconds(4));
        assertNotNull(a.await("boss-slam", 5), "Riss-Schlag kommt");
        a.send("{\"type\":\"boss-dodge\",\"bossId\":" + id + "}");
        Thread.sleep(200);

        // Finale ab 10 %: nur einer schreit → er brüllt zurück
        bosses.setHp(id, RiftBossService.MAX_HP / 10);
        assertNotNull(a.await("boss-finale", 5));
        a.send("{\"type\":\"boss-scream\",\"bossId\":" + id + ",\"db\":-5}");
        Thread.sleep(200);
        bosses.tick(Instant.now().plusSeconds(10));
        JsonNode roar = a.awaitMatching("boss-phase", n -> n.path("roar").asBoolean(), 5);
        assertNotNull(roar, "allein schreien reicht nicht");
        int hp = bosses.find(id).orElseThrow().hp();
        assertTrue(hp >= RiftBossService.MAX_HP / 4 && hp < RiftBossService.MAX_HP / 4 + 100, "heilt sich auf ein Viertel: " + hp);

        // Finale noch einmal – diesmal schreien beide
        bosses.setHp(id, RiftBossService.MAX_HP / 10);
        a.awaitMatching("boss-finale", n -> true, 5);
        a.send("{\"type\":\"boss-scream\",\"bossId\":" + id + ",\"db\":-8}");
        b.send("{\"type\":\"boss-scream\",\"bossId\":" + id + ",\"db\":-12}");
        Thread.sleep(300);
        bosses.tick(Instant.now().plusSeconds(10));
        JsonNode end = a.await("boss-end", 5);
        assertEquals("DEFEATED", end.get("result").asText());
        assertTrue(end.get("shards").asInt() >= RiftBossService.SHARDS_BASE);
        assertNotNull(b.await("boss-end", 5));
        assertTrue(shards(A) >= shardsA + RiftBossService.SHARDS_BASE);
        assertTrue(shards(B) >= shardsB + RiftBossService.SHARDS_BASE);
    }

    @Test
    void escapesWhenTimeRunsOut() throws Exception {
        RiftBossService.fightTime = Duration.ofMillis(100);
        long id = bosses.spawn("Platz", LAT, LON).id;
        WsTestClient a = connect(A), b = connect(B);
        a.send(join(id));
        b.send(join(id));
        a.awaitMatching("boss-state", n -> "FIGHT".equals(n.get("phase").asText()), 5);
        bosses.tick(Instant.now().plusSeconds(1));
        assertEquals("ESCAPED", a.await("boss-end", 5).get("result").asText());
    }
}
