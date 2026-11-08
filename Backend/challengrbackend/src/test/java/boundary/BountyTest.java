package boundary;

import com.fasterxml.jackson.databind.JsonNode;
import control.BattleRepository;
import control.BountyService;
import control.PlayerRepository;
import entity.Player;
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

/** Kopfgeld: Platz 1 trägt es, wer ihn in der Liga besiegt, kassiert den Bonus und übernimmt es. */
@QuarkusTest
class BountyTest {

    private static final String A = "demo-1";
    private static final String B = "demo-2";

    @TestHTTPResource("/ws/game")
    URI wsUri;

    @Inject
    BountyService bounty;

    @Inject
    PlayerRepository players;

    @Inject
    BattleRepository battles;

    @Inject
    jakarta.persistence.EntityManager em;

    private final List<WsTestClient> clients = new ArrayList<>();
    private int trophiesA, trophiesB;

    private void update(String id, java.util.function.Consumer<Player> change) {
        QuarkusTransaction.requiringNew().run(() -> change.accept(players.findById(id)));
    }

    private Player load(String id) {
        return QuarkusTransaction.requiringNew().call(() -> players.findById(id));
    }

    @BeforeEach
    void setUp() {
        QuarkusTransaction.requiringNew().run(() -> {
            em.createQuery("UPDATE Player p SET p.bountySince = null WHERE p.bountySince IS NOT NULL").executeUpdate();
            battles.update("status = 'EXPIRED' where status not in ('DONE','EXPIRED','CANCELLED','DECLINED','ABANDONED')");
        });
        trophiesA = load(A).getTrophies();
        trophiesB = load(B).getTrophies();
        // A ist mit Abstand Platz 1, beide gerade aktiv
        update(A, p -> { p.setTrophies(9000); p.setLastSeenAt(Instant.now()); });
        update(B, p -> p.setLastSeenAt(Instant.now()));
    }

    @AfterEach
    void tearDown() throws Exception {
        for (WsTestClient c : clients) c.close();
        update(A, p -> { p.setTrophies(trophiesA); p.setBountySince(null); });
        update(B, p -> { p.setTrophies(trophiesB); p.setBountySince(null); });
    }

    @Test
    void numberOneGetsTheBounty() {
        assertEquals(A, bounty.refresh().getId());
        assertEquals(A, bounty.refresh().getId(), "bleibt beim Träger");
        Login.as(B).when().get("/api/leaderboard").then().statusCode(200)
                .body("school.find { it.playerId == 'demo-1' }.bounty", is(true));
    }

    @Test
    void beatingTheHolderPaysTheBonusAndPassesTheBounty() throws Exception {
        bounty.refresh();
        int claimedBefore = load(B).getBountiesClaimed();
        WsTestClient a = WsTestClient.connect(wsUri, A); clients.add(a);
        WsTestClient b = WsTestClient.connect(wsUri, B); clients.add(b);

        a.send("{\"type\":\"create-battle\",\"toId\":\"" + B + "\",\"mode\":\"RANKED_REALLIFE\"}");
        JsonNode requested = b.await("battle-requested", 5);
        assertNotNull(requested);
        long battleId = requested.get("battleId").asLong();
        b.send("{\"type\":\"update-battle-status\",\"battleId\":" + battleId + ",\"status\":\"ACCEPTED\"}");
        assertNotNull(a.awaitStatus("ACCEPTED", 5));
        int before = load(B).getTrophies();
        a.send("{\"type\":\"update-battle-status\",\"battleId\":" + battleId + ",\"status\":\"DONE_SURRENDER\"}");

        JsonNode result = b.await("battle-result", 5);
        assertNotNull(result);
        assertEquals(B, result.get("winnerId").asText());
        assertEquals(BountyService.BONUS, result.get("bountyBonus").asInt());
        int delta = result.get("winnerPointsDelta").asInt();
        assertTrue(delta > BountyService.BONUS, "Bonus steckt im Trophäen-Gewinn");
        assertEquals(before + delta, load(B).getTrophies());
        assertTrue(load(B).hasBounty(), "der Jäger trägt jetzt das Kopfgeld");
        assertFalse(load(A).hasBounty());
        assertEquals(claimedBefore + 1, load(B).getBountiesClaimed());
    }

    @Test
    void idleHolderLosesTheBounty() {
        bounty.refresh();
        update(A, p -> p.setLastSeenAt(Instant.now().minus(Duration.ofHours(25))));
        update(B, p -> p.setTrophies(8000));
        assertEquals(B, bounty.refresh().getId(), "geht an den aktiven Platz 1");
        assertFalse(load(A).hasBounty());
    }
}
