package boundary;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

@QuarkusTest
class ChallengeResourceTest {

    // ----------------------------------------------------- App-Endpunkte

    @Test
    void categoryListForAppHasChoicesButNoAnswer() {
        List<Map<String, Object>> wissen = given()
                .when().get("/api/challenges/Wissen")
                .then().statusCode(200)
                .extract().jsonPath().getList("$");

        assertFalse(wissen.isEmpty());
        for (Map<String, Object> ch : wissen) {
            assertEquals("Wissen", ch.get("category"));
            assertEquals(4, ((List<?>) ch.get("choices")).size());
            assertNull(ch.get("correctIndex"), "App darf die richtige Antwort nicht bekommen");
        }
    }

    @Test
    void singleChallengeForAppHasNoAnswer() {
        Number id = given().when().get("/api/challenges/Wissen")
                .then().statusCode(200)
                .extract().path("[0].id");

        given().when().get("/api/challenges/id/" + id)
                .then().statusCode(200)
                .body("id", equalTo(id.intValue()))
                .body("correctIndex", nullValue())
                .body("choices.size()", equalTo(4));
    }

    @Test
    void unknownChallengeIs404() {
        given().when().get("/api/challenges/id/999999")
                .then().statusCode(404);
    }

    @Test
    void nonKnowledgeChallengesHaveNoChoices() {
        given().when().get("/api/challenges/Fitness")
                .then().statusCode(200)
                .body("size()", greaterThan(0))
                .body("choices", everyItem(nullValue()))
                .body("category", everyItem(equalTo("Fitness")));
    }

    @Test
    void everyCategoryUsedByTheAppExists() {
        for (String category : List.of("Fitness", "Mutprobe", "Wissen", "iPhone", "Customer")) {
            given().when().get("/api/challenges/" + category)
                    .then().statusCode(200);
        }
    }

    // ----------------------------------------------------- Dashboard

    @Test
    void dashboardListStillContainsTheAnswer() {
        List<Map<String, Object>> all = given()
                .when().get("/api/challenges")
                .then().statusCode(200)
                .extract().jsonPath().getList("$");

        assertTrue(all.stream()
                .filter(ch -> "Wissen".equals(ch.get("category")))
                .allMatch(ch -> ch.get("correctIndex") != null), "Dashboard braucht die Antwort zum Verwalten");
    }

    @Test
    void createKnowledgeChallenge() {
        given().contentType("application/json")
                .body("""
                        {"text":"Test-Frage?","category":"Wissen","choices":["a","b","c","d"],"correctIndex":2}
                        """)
                .when().post("/api/challenges")
                .then().statusCode(200)
                .body("id", notNullValue())
                .body("correctIndex", equalTo(2));
    }

    @Test
    void createRejectsInvalidInput() {
        given().contentType("application/json").body("{\"category\":\"Fitness\"}")
                .when().post("/api/challenges").then().statusCode(400);

        given().contentType("application/json").body("{\"text\":\"x\",\"category\":\"Gibtsnicht\"}")
                .when().post("/api/challenges").then().statusCode(400);

        given().contentType("application/json")
                .body("{\"text\":\"x\",\"category\":\"Wissen\",\"choices\":[\"a\",\"b\"],\"correctIndex\":0}")
                .when().post("/api/challenges").then().statusCode(400);

        given().contentType("application/json")
                .body("{\"text\":\"x\",\"category\":\"Wissen\",\"choices\":[\"a\",\"b\",\"c\",\"d\"],\"correctIndex\":7}")
                .when().post("/api/challenges").then().statusCode(400);
    }

    @Test
    void allIPhoneChallengesAreAvailable() {
        List<String> texts = given().when().get("/api/challenges/iPhone")
                .then().statusCode(200)
                .extract().jsonPath().getList("text");

        // Jeder Typ braucht genau das Stichwort, an dem die App die Spezial-Ansicht erkennt
        for (String keyword : List.of("Sprint-Challenge", "Check-In-Spot", "Kompass", "Shake",
                "Schrei-Challenge", "Foto", "Liegestütz")) {
            assertTrue(texts.stream().anyMatch(t -> t.contains(keyword)), "iPhone-Challenge fehlt: " + keyword);
        }
    }
}
