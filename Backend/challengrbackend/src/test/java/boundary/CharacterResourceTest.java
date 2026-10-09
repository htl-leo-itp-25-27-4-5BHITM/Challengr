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
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":" + lat + ",\"longitude\":" + lon + "}")
                .when().post("/api/players")
                .then().statusCode(anyOf(is(200), is(204)));
        return id;
    }

    private static String body(String character) {
        return "{\"character\":\"" + character + "\"}";
    }

    @Test
    void newPlayerHasOnlyTheStartersUnlocked() {
        String id = newPlayer("char-new-" + System.nanoTime(), 48.3, 14.3);

        List<Map<String, Object>> list = Login.as(id).when().get("/api/players/" + id + "/characters")
                .then().statusCode(200).extract().jsonPath().getList("$");

        Map<String, Boolean> unlocked = new java.util.HashMap<>();
        for (Map<String, Object> c : list) unlocked.put((String) c.get("id"), (Boolean) c.get("unlocked"));
        assertEquals(Boolean.TRUE, unlocked.get("junge"));
        assertEquals(Boolean.TRUE, unlocked.get("maedchen"));
        for (String locked : List.of("sir-brecht", "ragnar", "hayato", "kage", "kai", "merlo", "lyra", "kaeptn-rex")) {
            assertEquals(Boolean.FALSE, unlocked.get(locked), locked + " ist am Anfang gesperrt");
        }
        assertEquals(10, list.size());
        Map<String, Object> lyra = list.stream().filter(c -> "lyra".equals(c.get("id"))).findFirst().orElseThrow();
        assertEquals("CHECKINS", lyra.get("requirement"));
        assertEquals(5, lyra.get("required"));
        assertEquals(0, lyra.get("progress"));
    }

    @Test
    void lockedOrUnknownCharacterCannotBeSelected() {
        String id = newPlayer("char-lock-" + System.nanoTime(), 48.3, 14.3);

        Login.as(id).contentType("application/json").body(body("sir-brecht"))
                .when().put("/api/players/" + id + "/character")
                .then().statusCode(403);
        Login.as(id).contentType("application/json").body(body("godzilla"))
                .when().put("/api/players/" + id + "/character")
                .then().statusCode(400);
    }

    @Test
    void selectedCharacterIsVisibleToOthersNearby() {
        String me = newPlayer("char-me-" + System.nanoTime(), 47.1, 15.1);
        String other = newPlayer("char-other-" + System.nanoTime(), 47.1001, 15.1001);

        Login.as(other).contentType("application/json").body(body("maedchen"))
                .when().put("/api/players/" + other + "/character")
                .then().statusCode(200).body("character", is("maedchen"));

        Login.as(me).when().get("/api/players/nearby?playerId=" + me + "&latitude=47.1&longitude=15.1&radius=200")
                .then().statusCode(200)
                .body("find { it.id == '" + other + "' }.character", is("maedchen"));
    }
}
