package at.htl;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;

@QuarkusTest
class ExampleResourceTest {
    @Test
    void testPlayersEndpoint() {
        given()
                .when().get("/api/players")
                .then()
                .statusCode(200);
    }

}