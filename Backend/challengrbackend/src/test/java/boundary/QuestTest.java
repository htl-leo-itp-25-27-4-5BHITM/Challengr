package boundary;

import control.QuestCatalog;
import control.QuestService;
import entity.*;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Tagesaufgaben (Coins) und Events (Beta-Event mit dem Crash-Test-Dummy). */
@QuarkusTest
class QuestTest {

    @Inject
    EntityManager em;

    @Inject
    control.QuestEventStore eventStore;

    private String newPlayer(String prefix) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":48.3,\"longitude\":14.3}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    private int coins(String id) {
        return Login.as(id).when().get("/api/quests").then().statusCode(200).extract().path("coins");
    }

    @Test
    void needsLogin() {
        given().when().get("/api/quests").then().statusCode(401);
        given().when().post("/api/quests/daily/VISIT/claim").then().statusCode(401);
    }

    @Test
    void dailyQuestsAreTheSameForEveryoneOnADay() {
        LocalDate day = LocalDate.of(2026, 10, 20);
        assertEquals(QuestCatalog.dailyFor(day), QuestCatalog.dailyFor(day));
        assertEquals(3, QuestCatalog.dailyFor(day).size());
        assertEquals("VISIT", QuestCatalog.dailyFor(day).get(0).id());
        // nicht jeden Tag dieselben
        long distinct = java.util.stream.IntStream.range(0, 14)
                .mapToObj(i -> QuestCatalog.dailyFor(day.plusDays(i)).subList(1, 3)).distinct().count();
        assertTrue(distinct > 3);
    }

    @Test
    void visitCanBeClaimedOnceAndUnfinishedTasksNot() {
        String me = newPlayer("quest");
        int before = coins(me);
        Login.as(me).when().get("/api/quests").then().statusCode(200)
                .body("daily.size()", is(3))
                .body("daily[0].id", is("VISIT"))
                .body("daily[0].progress", is(1))
                .body("daily[0].claimed", is(false))
                .body("resetsAt", notNullValue());

        Login.as(me).when().post("/api/quests/daily/VISIT/claim").then().statusCode(200)
                .body("coins", is(before + 10))
                .body("daily[0].claimed", is(true));
        Login.as(me).when().post("/api/quests/daily/VISIT/claim").then().statusCode(409);

        // neue Spieler haben noch keine Battles → die gelosten Aufgaben sind nicht geschafft
        String second = QuestCatalog.dailyFor(QuestService.today()).get(1).id();
        Login.as(me).when().post("/api/quests/daily/" + second + "/claim").then().statusCode(409);
        Login.as(me).when().post("/api/quests/daily/GIBTSNICHT/claim").then().statusCode(404);
        assertEquals(before + 10, coins(me));
    }

    @Test
    void finishingTheBetaEventUnlocksTheCrashTestDummy() {
        QuestCatalog.Event beta = eventStore.find("beta").orElseThrow();
        Assumptions.assumeTrue(beta.isActive(QuestService.today()), "Beta-Event läuft nicht mehr");

        String me = newPlayer("beta");
        String other = newPlayer("beta-opp");

        // Event noch nicht geschafft → Figur gesperrt, Abholen geht nicht
        Login.as(me).when().post("/api/quests/events/beta/claim").then().statusCode(409);
        Login.as(me).contentType("application/json").body("{\"character\":\"crash-dummy\"}")
                .when().put("/api/players/" + me + "/character").then().statusCode(403);

        LocalDate today = QuestService.today();
        QuarkusTransaction.requiringNew().run(() -> {
            Player a = em.find(Player.class, me), b = em.find(Player.class, other);
            Challenges challenge = em.createQuery("SELECT c FROM Challenges c", Challenges.class).setMaxResults(1).getSingleResult();
            for (int i = 0; i < 10; i++) {
                Battle battle = new Battle();
                battle.setFromPlayer(a);
                battle.setToPlayer(b);
                battle.setChallenge(challenge);
                battle.setCategory(em.createQuery("SELECT c FROM ChallengeCategory c", ChallengeCategory.class).setMaxResults(1).getSingleResult());
                battle.setType(i < 3 ? "RANKED_KNOWLEDGE" : "FRIENDLY");
                battle.setStatus("DONE");
                battle.setStatusChangedAt(LocalDateTime.now());
                em.persist(battle);
            }
            for (int i = 0; i < 5; i++) {
                LocalDate d = beta.start().plusDays(i);
                if (!d.equals(today)) em.persist(new PlayerActivity(me, d));
            }
            if (!beta.start().plusDays(5).isAfter(today)) em.persist(new PlayerActivity(me, beta.start().plusDays(5)));
            for (int i = 0; i < 2; i++) {
                HotspotCheckin c = new HotspotCheckin();
                c.setPlayerId(me);
                c.setHotspotId("test-" + i);
                c.setDay(beta.start().plusDays(i));
                em.persist(c);
            }
            Friendship f = new Friendship();
            f.setPlayerAId(me.compareTo(other) < 0 ? me : other);
            f.setPlayerBId(me.compareTo(other) < 0 ? other : me);
            em.persist(f);
            for (int i = 0; i < 6; i++) em.persist(new QuestClaim(me, "daily:test:" + i, beta.start().plusDays(i), 0));
        });

        int before = coins(me);
        Login.as(me).when().get("/api/quests").then().statusCode(200)
                .body("events.find { it.id == 'beta' }.completed", is(true))
                .body("events.find { it.id == 'beta' }.rewardCharacter", is("crash-dummy"))
                .body("events.find { it.id == 'beta' }.tasks.size()", is(6));
        Login.as(me).when().post("/api/quests/events/beta/claim").then().statusCode(200)
                .body("coins", is(before + 100))
                .body("events.find { it.id == 'beta' }.claimed", is(true));
        Login.as(me).when().post("/api/quests/events/beta/claim").then().statusCode(409);

        List<java.util.Map<String, Object>> chars = Login.as(me).when().get("/api/players/" + me + "/characters")
                .then().statusCode(200).extract().jsonPath().getList("$");
        var dummy = chars.stream().filter(c -> "crash-dummy".equals(c.get("id"))).findFirst().orElseThrow();
        assertEquals("EVENT", dummy.get("requirement"));
        assertEquals(true, dummy.get("unlocked"));
        Login.as(me).contentType("application/json").body("{\"character\":\"crash-dummy\"}")
                .when().put("/api/players/" + me + "/character").then().statusCode(200);
    }

    @Test
    void deletingTheAccountRemovesClaims() {
        String me = newPlayer("quest-del");
        Login.as(me).when().post("/api/quests/daily/VISIT/claim").then().statusCode(200);
        Login.as(me).when().delete("/api/players/me").then().statusCode(anyOf(is(200), is(204)));
        long left = QuarkusTransaction.requiringNew().call(() -> em.createQuery(
                "SELECT COUNT(c) FROM QuestClaim c WHERE c.playerId = :p", Long.class).setParameter("p", me).getSingleResult());
        assertEquals(0, left);
    }
}
