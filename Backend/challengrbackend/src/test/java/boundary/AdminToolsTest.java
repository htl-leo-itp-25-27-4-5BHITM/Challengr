package boundary;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/** Dashboard-Werkzeuge: Korrekturen mit Protokoll, Systemstatus, Backups. */
@QuarkusTest
class AdminToolsTest {

    private String newPlayer(String prefix) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":48.3,\"longitude\":14.3}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    @Test
    void onlyAdmins() {
        String p = newPlayer("adm-no");
        for (String path : new String[]{"/api/admin/status", "/api/admin/backups", "/api/admin/audit"}) {
            given().when().get(path).then().statusCode(401);
            Login.as(p).when().get(path).then().statusCode(403);
        }
        Login.as(p).contentType("application/json").body("{\"trophies\":9999,\"reason\":\"ich will\"}")
                .when().post("/api/admin/corrections/" + p + "").then().statusCode(403);
    }

    @Test
    void adjustNeedsAReasonAndIsLogged() {
        String p = newPlayer("adm-adj");
        Login.admin().contentType("application/json").body("{\"trophies\":500}")
                .when().post("/api/admin/corrections/" + p + "").then().statusCode(400);
        Login.admin().contentType("application/json").body("{\"trophies\":-1,\"reason\":\"Test\"}")
                .when().post("/api/admin/corrections/" + p + "").then().statusCode(400);

        Login.admin().contentType("application/json").body("{\"trophies\":1342,\"coins\":50,\"reason\":\"Test-Gutschrift\"}")
                .when().post("/api/admin/corrections/" + p + "").then().statusCode(200)
                .body("trophies", is(1342)).body("highestTrophies", is(1342)).body("coins", is(50));
        // zurück auf 200 und Rekord mit zurücksetzen (Fall bin_der_dominik)
        Login.admin().contentType("application/json").body("{\"trophies\":200,\"resetRecord\":true,\"reason\":\"Test rückgängig\"}")
                .when().post("/api/admin/corrections/" + p + "").then().statusCode(200)
                .body("trophies", is(200)).body("highestTrophies", is(200));

        Login.admin().when().get("/api/admin/audit?playerId=" + p).then().statusCode(200)
                .body("size()", is(4))
                .body("action", hasItems("TROPHIES", "COINS", "RECORD"))
                .body("reason", hasItem("Test-Gutschrift"))
                .body("[0].adminName", notNullValue());
        Login.admin().contentType("application/json").body("{\"trophies\":1,\"reason\":\"egal\"}")
                .when().post("/api/admin/corrections/gibts-nicht").then().statusCode(404);
    }

    @Test
    void statusShowsChecks() {
        Login.admin().when().get("/api/admin/status").then().statusCode(200)
                .body("players", greaterThanOrEqualTo(0))
                .body("online", greaterThanOrEqualTo(0))
                .body("checks.name", hasItems("Datenbank", "Backups"))
                .body("checks.find { it.name == 'Datenbank' }.state", is("ok"));
    }

    @Test
    void keycloakUrlIsResolvedFromTheConfig() {
        String url = org.eclipse.microprofile.config.ConfigProvider.getConfig()
                .getValue("challengr.status.keycloak-url", String.class);
        org.junit.jupiter.api.Assertions.assertTrue(url.startsWith("http"), "keine unaufgelöste ${…}-Angabe: " + url);
        java.net.URI.create(url);
    }

    @Test
    void backupsWithoutPostgresAreReportedNotCrashed() {
        // im Test läuft H2, kein pg_dump → keine Backups, aber eine klare Antwort
        Login.admin().when().get("/api/admin/backups").then().statusCode(200)
                .body("available", is(false)).body("files", notNullValue());
        Login.admin().when().post("/api/admin/backups").then().statusCode(anyOf(is(409), is(503)))
                .body("message", notNullValue());
        Login.admin().when().get("/api/admin/backups/..%2F..%2Fetc%2Fpasswd").then().statusCode(404);
        Login.admin().when().get("/api/admin/backups/challengr-2026-01-01-000000-auto.sql.gz").then().statusCode(404);
    }
}
