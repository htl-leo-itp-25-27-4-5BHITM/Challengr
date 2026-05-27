package boundary;

import entity.Player;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import control.BanEnforcementService;

@QuarkusTest
class BanEnforcementFilterTest {

    @Inject
    EntityManager em;

    @Test
    void bannedPlayerGets403() {
        String pid = "test-banned";
        seed(pid, Instant.now().plusSeconds(3600), "too loud");

        // sanity: record exists in DB
        Player persisted = em.find(Player.class, pid);
        org.junit.jupiter.api.Assertions.assertNotNull(persisted);
        org.junit.jupiter.api.Assertions.assertNotNull(persisted.getBanUntil());

        given()
        .header(BanEnforcementService.PLAYER_ID_HEADER, pid)
                .when().get("/api/friends/list?playerId=" + pid)
                .then()
                .statusCode(403)
                .body("error", equalTo("banned"))
                .body("banUntil", notNullValue())
                .body("banReason", equalTo("too loud"));
    }

    @Test
    void nonBannedPlayerPassesThrough() {
        String pid = "test-ok";
        seed(pid, null, null);

        // The friends list endpoint will still fail because friendship data is missing,
        // but the important part is: not 403.
        given()
        .header(BanEnforcementService.PLAYER_ID_HEADER, pid)
                .when().get("/api/friends/list?playerId=" + pid)
                .then()
                .statusCode(not(403));
    }

    @Transactional
    void seed(String id, Instant banUntil, String reason) {
        Player p = em.find(Player.class, id);
        if (p == null) {
            p = new Player();
            p.setId(id);
        }

        p.setName(id);
        p.setLatitude(0);
        p.setLongitude(0);
        p.setPoints(0);
        p.setConsecutiveConflicts(0);
        p.setBanUntil(banUntil);
        p.setBanReason(reason);

        if (!em.contains(p)) {
            em.persist(p);
        }
        em.flush();
    }
}
