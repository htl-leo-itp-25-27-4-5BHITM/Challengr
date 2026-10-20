package boundary;

import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/** Ranglisten (Top 10, Freunde, eigener Platz) und Spielersuche per Namen. */
@QuarkusTest
class LeaderboardTest {

    @Inject
    EntityManager em;

    private String newPlayer(String prefix) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":48.3,\"longitude\":14.3}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    private void setTrophies(String id, int trophies) {
        QuarkusTransaction.requiringNew().run(() -> em.createQuery(
                        "UPDATE Player p SET p.trophies = :t, p.highestTrophies = :t WHERE p.id = :id")
                .setParameter("t", trophies).setParameter("id", id).executeUpdate());
    }

    private void befriend(String a, String b) {
        long requestId = ((Number) Login.as(a).contentType("application/json")
                .body("{\"fromPlayerId\":\"" + a + "\",\"toPlayerId\":\"" + b + "\"}")
                .when().post("/api/friends/requests").then().statusCode(200).extract().path("id")).longValue();
        Login.as(b).contentType("application/json").when().post("/api/friends/requests/" + requestId + "/accept")
                .then().statusCode(200);
    }

    @Test
    void needsLogin() {
        given().when().get("/api/leaderboard").then().statusCode(401);
        given().when().get("/api/players/search?q=ab").then().statusCode(401);
    }

    @Test
    void topTenFriendsAndOwnPlace() {
        String top = newPlayer("lb-top");
        String friend = newPlayer("lb-friend");
        String me = newPlayer("lb-me");
        String stranger = newPlayer("lb-stranger");
        setTrophies(top, 99_999);
        setTrophies(friend, 300);
        setTrophies(me, 250);
        setTrophies(stranger, 260);
        befriend(me, friend);

        Login.as(me).when().get("/api/leaderboard").then().statusCode(200)
                .body("school.size()", lessThanOrEqualTo(10))
                .body("school[0].playerId", is(top))
                .body("school[0].place", is(1))
                .body("school[0].trophies", is(99_999))
                .body("school[0].rankName", is("Challengr"))
                // Freunde: nur Freunde + man selbst, nach Trophäen
                .body("friends.playerId", contains(friend, me))
                .body("friends[1].me", is(true))
                .body("me.playerId", is(me))
                .body("me.trophies", is(250))
                .body("me.place", greaterThan(1))
                .body("totalPlayers", greaterThanOrEqualTo(4))
                // nie ein Standort
                .body("school[0].latitude", nullValue());
    }

    @Test
    void noSecondRequestBetweenFriends() {
        String a = newPlayer("fr-a");
        String b = newPlayer("fr-b");
        befriend(a, b);
        Login.as(a).contentType("application/json")
                .body("{\"fromPlayerId\":\"" + a + "\",\"toPlayerId\":\"" + b + "\"}")
                .when().post("/api/friends/requests").then().statusCode(409);
    }

    @Test
    void blockedPlayersAreHidden() {
        String top = newPlayer("lb-blocked");
        String me = newPlayer("lb-blocker");
        setTrophies(top, 199_999);
        Login.as(me).when().post("/api/safety/blocks/" + top).then().statusCode(204);
        Login.as(me).when().get("/api/leaderboard").then().statusCode(200)
                .body("school.playerId", not(hasItem(top)));
    }

    @Test
    void searchFindsPlayersByNameWithoutLocation() {
        String me = newPlayer("search-me");
        String other = newPlayer("search-zorro");
        Login.as(me).when().get("/api/players/search?q=" + other.substring(7, 15)).then().statusCode(200)
                .body("id", hasItem(other))
                .body("id", not(hasItem(me)))
                .body("[0].latitude", nullValue());
        // zu kurz → leer, Sonderzeichen sind harmlos
        Login.as(me).when().get("/api/players/search?q=s").then().statusCode(200).body("size()", is(0));
        Login.as(me).when().get("/api/players/search?q=%25%25").then().statusCode(200).body("size()", is(0));
    }
}
