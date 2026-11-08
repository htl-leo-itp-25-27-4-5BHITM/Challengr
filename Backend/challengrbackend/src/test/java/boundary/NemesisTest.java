package boundary;

import entity.Battle;
import entity.Challenges;
import entity.Player;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;

import static org.hamcrest.Matchers.*;

/** Erzfeind: meistgespielter Gegner ab 3 Battles, mit Bilanz. */
@QuarkusTest
class NemesisTest {

    @Inject
    EntityManager em;

    private String newPlayer(String prefix) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":48.3,\"longitude\":14.3}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    /** Fertiges Battle zwischen a und b; winner null = unentschieden. */
    private void battle(String a, String b, String winner) {
        QuarkusTransaction.requiringNew().run(() -> {
            Challenges c = em.find(Challenges.class, 1L);
            Battle x = new Battle();
            x.setFromPlayer(em.find(Player.class, a));
            x.setToPlayer(em.find(Player.class, b));
            x.setChallenge(c);
            x.setCategory(c.getChallengeCategory());
            x.setType("RANKED_REALLIFE");
            x.setStatus("DONE");
            x.setWinner(winner == null ? null : em.find(Player.class, winner));
            em.persist(x);
        });
    }

    @Test
    void noNemesisBeforeThreeBattles() {
        String me = newPlayer("nem-a"), other = newPlayer("nem-b");
        battle(me, other, me);
        battle(other, me, other);
        Login.as(me).when().get("/api/nemesis").then().statusCode(204);
    }

    @Test
    void mostPlayedOpponentWithRecord() {
        String me = newPlayer("nem-me"), rival = newPlayer("nem-rival"), casual = newPlayer("nem-casual");
        battle(me, rival, me);
        battle(rival, me, me);
        battle(me, rival, rival);
        battle(rival, me, null);
        battle(me, casual, me);
        battle(me, casual, me);
        battle(casual, me, me);

        Login.as(me).when().get("/api/nemesis").then().statusCode(200)
                .body("playerId", is(rival))
                .body("battles", is(4))
                .body("wins", is(2))
                .body("losses", is(1));
    }
}
