package boundary;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static org.hamcrest.Matchers.*;

/** Eigenen Namen ändern – und nicht von Login oder Standort-Updates überschreiben lassen. */
@QuarkusTest
class RenameTest {

    private String newPlayer(String prefix, String name) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + name + "\",\"latitude\":48.3,\"longitude\":14.3}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    private static String body(String name) {
        return "{\"name\":\"" + name + "\"}";
    }

    @Test
    void renameStaysAfterLoginAndLocationUpdates() {
        String id = newPlayer("ren", "keycloak_name_" + System.nanoTime() % 1000);
        String wanted = "Neuer Name " + System.nanoTime() % 100000;

        Login.as(id).contentType("application/json").body(body("  " + wanted + "  "))
                .when().put("/api/players/" + id + "/name")
                .then().statusCode(200).body("name", is(wanted));

        // Login legt den Spieler erneut "an" (mit Keycloak-Namen), Standort-Update schickt ihn auch mit
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"keycloak_name\",\"latitude\":48.3,\"longitude\":14.3}")
                .when().post("/api/players").then().statusCode(200).body("name", is(wanted));
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"keycloak_name\",\"latitude\":48.31,\"longitude\":14.31}")
                .when().put("/api/players/" + id).then().statusCode(200).body("name", is(wanted));
    }

    @Test
    void invalidTakenOrForeignNamesAreRejected() {
        String a = newPlayer("ren-a", "Anna" + System.nanoTime() % 100000);
        String b = newPlayer("ren-b", "Ben" + System.nanoTime() % 100000);
        String taken = "Vergeben" + System.nanoTime() % 100000;
        Login.as(a).contentType("application/json").body(body(taken))
                .when().put("/api/players/" + a + "/name").then().statusCode(200);

        Login.as(b).contentType("application/json").body(body(taken.toUpperCase()))
                .when().put("/api/players/" + b + "/name").then().statusCode(409).body(containsString("gibt es schon"));
        Login.as(b).contentType("application/json").body(body("ab"))
                .when().put("/api/players/" + b + "/name").then().statusCode(400).body(containsString("mindestens"));
        Login.as(b).contentType("application/json").body(body("<script>"))
                .when().put("/api/players/" + b + "/name").then().statusCode(400);
        Login.as(b).contentType("application/json").body(body("Arschloch99"))
                .when().put("/api/players/" + b + "/name").then().statusCode(400).body(containsString("nicht erlaubt"));
        Login.as(b).contentType("application/json").body(body("Fremd" + System.nanoTime() % 1000))
                .when().put("/api/players/" + a + "/name").then().statusCode(403);
    }
}
