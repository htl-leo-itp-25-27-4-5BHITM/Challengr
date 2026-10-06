package boundary;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Spielfiguren: Auswahl, Freischalten und Anzeige bei anderen Spielern. */
@QuarkusTest
class CharacterResourceTest {

    private String newPlayer(String id, double lat, double lon) {
        given().contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":" + lat + ",\"longitude\":" + lon + "}")
                .when().post("/api/players")
                .then().statusCode(anyOf(is(200), is(204)));
        return id;
    }

    private static String body(String character) {
        return "{\"character\":\"" + character + "\"}";
    }

    @Test
    void newPlayerSeesStarterCharactersUnlockedAndHayatoLocked() {
        String id = newPlayer("char-new-" + System.nanoTime(), 48.3, 14.3);

        List<Map<String, Object>> list = given().when().get("/api/players/" + id + "/characters")
                .then().statusCode(200).extract().jsonPath().getList("$");

        Map<String, Boolean> unlocked = new java.util.HashMap<>();
        for (Map<String, Object> c : list) unlocked.put((String) c.get("id"), (Boolean) c.get("unlocked"));
        assertEquals(Boolean.TRUE, unlocked.get("sir-brecht"));
        assertEquals(Boolean.TRUE, unlocked.get("ragnar"));
        assertEquals(Boolean.FALSE, unlocked.get("hayato"), "Hayato erst nach 3 Siegen");
    }

    @Test
    void lockedOrUnknownCharacterCannotBeSelected() {
        String id = newPlayer("char-lock-" + System.nanoTime(), 48.3, 14.3);

        given().contentType("application/json").body(body("hayato"))
                .when().put("/api/players/" + id + "/character")
                .then().statusCode(403);
        given().contentType("application/json").body(body("godzilla"))
                .when().put("/api/players/" + id + "/character")
                .then().statusCode(400);
    }

    @Test
    void selectedCharacterIsVisibleToOthersNearby() {
        String me = newPlayer("char-me-" + System.nanoTime(), 47.1, 15.1);
        String other = newPlayer("char-other-" + System.nanoTime(), 47.1001, 15.1001);

        given().contentType("application/json").body(body("ragnar"))
                .when().put("/api/players/" + other + "/character")
                .then().statusCode(200).body("character", is("ragnar"));

        given().when().get("/api/players/nearby?playerId=" + me + "&latitude=47.1&longitude=15.1&radius=200")
                .then().statusCode(200)
                .body("find { it.id == '" + other + "' }.character", is("ragnar"));
    }
}
