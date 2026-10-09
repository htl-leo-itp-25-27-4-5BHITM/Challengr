package control;

import entity.Player;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

/** B4: nach einem Jahr ohne Aktivität wird das Konto gelöscht, aktive bleiben. */
@QuarkusTest
class InactiveAccountCleanupTest {

    @Inject
    InactiveAccountCleanup cleanup;

    @Inject
    PlayerRepository playerRepository;

    private String player(String prefix, Instant lastSeen) {
        String id = prefix + "-" + System.nanoTime();
        QuarkusTransaction.requiringNew().run(() -> {
            Player p = new Player(id, 0, 0);
            p.setId(id);
            p.setLastSeenAt(lastSeen);
            playerRepository.createPlayer(p);
        });
        return id;
    }

    @Test
    void deletesOnlyLongInactiveAccounts() {
        Instant now = Instant.now();
        String old = player("ret-old", now.minus(Duration.ofDays(400)));
        String active = player("ret-active", now.minus(Duration.ofDays(30)));
        String unknown = player("ret-unknown", null);

        assertTrue(cleanup.run(now) >= 1);

        assertNull(QuarkusTransaction.requiringNew().call(() -> playerRepository.findById(old)));
        assertNotNull(QuarkusTransaction.requiringNew().call(() -> playerRepository.findById(active)));
        assertNotNull(QuarkusTransaction.requiringNew().call(() -> playerRepository.findById(unknown)));
    }
}
