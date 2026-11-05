package boundary;

import control.AdminStatsService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Dashboard-Analysen: nur für Admins, echte Zahlen, Aktivität wird erfasst und beim Löschen entfernt. */
@QuarkusTest
class AdminStatsTest {

    @Inject
    EntityManager em;

    private String newPlayer(String prefix) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":48.3,\"longitude\":14.3}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    private long activityRows(String id) {
        return QuarkusTransaction.requiringNew().call(() -> em.createQuery(
                "SELECT COUNT(a) FROM PlayerActivity a WHERE a.playerId = :p", Long.class).setParameter("p", id).getSingleResult());
    }

    @Test
    void onlyAdminsSeeStats() {
        given().when().get("/api/admin/stats").then().statusCode(401);
        Login.as("normal-" + System.nanoTime()).when().get("/api/admin/stats").then().statusCode(403);
    }

    @Test
    void statsHaveTheExpectedShape() {
        newPlayer("stats");
        Map<String, Object> s = Login.admin().when().get("/api/admin/stats?days=14")
                .then().statusCode(200)
                .body("days", is(14))
                .body("daily.size()", is(14))
                .body("battlesByHour.size()", is(24))
                .body("modes.name", contains("Quiz-Show", "Real-Life", "Friendly"))
                .body("ranks.name", hasItems("Quitter", "Scrapper", "Challengr"))
                .body("totals.players", greaterThan(0))
                .body("totals.activeToday", greaterThan(0))
                .extract().jsonPath().getMap("$");
        List<?> leaderboard = (List<?>) s.get("leaderboard");
        assertTrue(leaderboard.size() <= 10);
        // Zeitraum wird begrenzt
        Login.admin().when().get("/api/admin/stats?days=1000").then().statusCode(200).body("days", is(90));
    }

    @Test
    void activityIsRecordedOncePerDayAndDeletedWithTheAccount() {
        String id = newPlayer("act");
        Login.as(id).contentType("application/json").body("{\"latitude\":48.31,\"longitude\":14.31}")
                .when().put("/api/players/" + id).then().statusCode(200);
        assertEquals(1, activityRows(id), "ein Eintrag pro Tag, auch bei mehreren Updates");

        Login.as(id).when().delete("/api/players/me").then().statusCode(204);
        assertEquals(0, activityRows(id), "Konto löschen entfernt auch die Aktivität");
    }

    private static io.restassured.specification.RequestSpecification given() {
        return io.restassured.RestAssured.given();
    }
}
