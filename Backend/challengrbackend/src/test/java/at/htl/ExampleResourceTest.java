package at.htl;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;

@QuarkusTest
class ExampleResourceTest {
    @Test
    void testPlayersEndpoint() {
        // Liste aller Spieler (mit Standort) nur für Admins
        given().when().get("/api/players").then().statusCode(401);
        given().header("X-Player-Id", "demo-1").when().get("/api/players").then().statusCode(403);
        given().header("X-Player-Id", "test-admin").header("X-Player-Roles", "admin")
                .when().get("/api/players")
                .then()
                .statusCode(200);
    }

}