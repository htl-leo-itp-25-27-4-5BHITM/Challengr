package boundary;

import control.AccountDeletionService;
import control.BattleMode;
import control.PlayerRepository;
import entity.Battle;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.*;

/** B1: Konto löschen – keine Daten mehr zur Player-ID, Battles der Gegner bleiben anonymisiert. */
@QuarkusTest
class AccountDeletionTest {

    @Inject
    PlayerRepository playerRepository;

    @Inject
    BattleService battleService;

    @Inject
    EntityManager em;

    private String newPlayer(String prefix) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":46.9,\"longitude\":14.9}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    private long count(String jpql, String id) {
        return QuarkusTransaction.requiringNew().call(() ->
                em.createQuery(jpql, Long.class).setParameter("id", id).getSingleResult());
    }

    @Test
    void deletingTheAccountRemovesAllPersonalData() {
        String a = newPlayer("del-a");
        String b = newPlayer("del-b");

        // Freundschaft A–B und ein Geschenk
        long requestId = ((Number) Login.as(a).contentType("application/json")
                .body("{\"fromPlayerId\":\"" + a + "\",\"toPlayerId\":\"" + b + "\"}")
                .when().post("/api/friends/requests").then().statusCode(200).extract().path("id")).longValue();
        Login.as(b).contentType("application/json").when().post("/api/friends/requests/" + requestId + "/accept").then().statusCode(200);
        Login.as(a).contentType("application/json").body("{\"fromPlayerId\":\"" + a + "\",\"toPlayerId\":\"" + b + "\"}")
                .when().post("/api/friends/gifts").then().statusCode(200);

        // Ein Battle A gegen B
        long challengeId = QuarkusTransaction.requiringNew().call(() ->
                em.createQuery("SELECT c.id FROM Challenges c ORDER BY c.id", Long.class).setMaxResults(1).getSingleResult());
        Battle battle = QuarkusTransaction.requiringNew().call(() ->
                battleService.createRequestedBattle(a, b, challengeId, BattleMode.FRIENDLY));

        given().when().delete("/api/players/me").then().statusCode(401);
        Login.as(a).when().delete("/api/players/me").then().statusCode(204);

        assertNull(QuarkusTransaction.requiringNew().call(() -> playerRepository.findById(a)), "Spieler gelöscht");
        assertEquals(0, count("SELECT COUNT(f) FROM Friendship f WHERE f.playerAId = :id OR f.playerBId = :id", a));
        assertEquals(0, count("SELECT COUNT(r) FROM FriendRequest r WHERE r.fromPlayerId = :id OR r.toPlayerId = :id", a));
        assertEquals(0, count("SELECT COUNT(g) FROM FriendGift g WHERE g.fromPlayerId = :id OR g.toPlayerId = :id", a));
        assertEquals(0, count("SELECT COUNT(b) FROM Battle b WHERE b.fromPlayer.id = :id OR b.toPlayer.id = :id", a));

        // B behält das Battle, aber nur noch mit dem anonymen Platzhalter
        String opponent = QuarkusTransaction.requiringNew().call(() ->
                em.find(Battle.class, battle.getId()).getFromPlayer().getId());
        assertEquals(AccountDeletionService.DELETED_PLAYER_ID, opponent);
        Login.as(b).when().get("/api/friends/list?playerId=" + b).then().statusCode(200)
                .body("size()", org.hamcrest.Matchers.is(0));

        // nochmal löschen ist harmlos
        Login.as(a).when().delete("/api/players/me").then().statusCode(204);
    }
}
