package boundary;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import control.AppStoreConnectClient;
import io.quarkus.test.junit.QuarkusMock;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** TestFlight-Feedback im Dashboard – mit vorgetäuschten Antworten von Apple. */
@QuarkusTest
class AdminFeedbackTest {

    /** Spielt App Store Connect: eine App, ein Screenshot-Feedback, ein Absturz. */
    static class FakeAsc extends AppStoreConnectClient {
        final List<String> calls = new ArrayList<>();
        final ObjectMapper m = new ObjectMapper();

        @Override public boolean isConfigured() { return true; }
        @Override public String appId() { return "app1"; }

        @Override
        public JsonNode get(String path) {
            calls.add(path);
            try {
                if (path.contains("betaFeedbackScreenshotSubmissions")) return m.readTree("""
                    {"data":[{"id":"shot-1","type":"betaFeedbackScreenshotSubmissions",
                      "attributes":{"createdDate":"2026-10-18T10:00:00Z","comment":"Knopf ist abgeschnitten",
                        "email":"tester@example.com","deviceModel":"iPhone15,2","osVersion":"18.6",
                        "screenshots":[{"url":"https://example.com/s.png","width":1170,"height":2532}]},
                      "relationships":{"build":{"data":{"type":"builds","id":"b1"}},"tester":{"data":{"type":"betaTesters","id":"t1"}}}}],
                     "included":[{"type":"builds","id":"b1","attributes":{"version":"2610161702"}},
                                 {"type":"betaTesters","id":"t1","attributes":{"firstName":"Lena","lastName":"K"}}],
                     "links":{}}""");
                if (path.contains("betaFeedbackCrashSubmissions/crash-1/crashLog")) return m.readTree("""
                    {"data":{"type":"betaCrashLogs","id":"x","attributes":{"logText":"Thread 0 Crashed: MapView"}}}""");
                if (path.contains("betaFeedbackCrashSubmissions")) return m.readTree("""
                    {"data":[{"id":"crash-1","type":"betaFeedbackCrashSubmissions",
                      "attributes":{"createdDate":"2026-10-19T08:00:00Z","comment":null,"deviceModel":"iPhone12,1","osVersion":"18.5"}}],
                     "links":{}}""");
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            throw new AppStoreConnectClient.AscException(404, "unbekannt: " + path);
        }
    }

    @Test
    void onlyAdmins() {
        io.restassured.RestAssured.given().when().get("/api/admin/feedback").then().statusCode(401);
        Login.as("player-" + System.nanoTime()).when().get("/api/admin/feedback").then().statusCode(403);
    }

    @Test
    void withoutKeyTheFeatureIsSimplyOff() {
        Login.admin().when().get("/api/admin/feedback").then().statusCode(200)
                .body("configured", is(false)).body("items", empty());
    }

    @Test
    void listsFeedbackAndRemembersDone() {
        FakeAsc fake = new FakeAsc();
        QuarkusMock.installMockForType(fake, AppStoreConnectClient.class);

        Login.admin().when().get("/api/admin/feedback?refresh=true").then().statusCode(200)
                .body("configured", is(true))
                .body("items.id", contains("crash-1", "shot-1"))   // neueste zuerst
                .body("items[1].comment", is("Knopf ist abgeschnitten"))
                .body("items[1].tester", is("Lena K"))
                .body("items[1].appVersion", is("2610161702"))
                .body("items[1].screenshots[0]", is("https://example.com/s.png"))
                .body("items[0].kind", is("CRASH"))
                .body("items[1].done", is(false));
        assertTrue(fake.calls.stream().anyMatch(c -> c.contains("include=build,tester")));

        Login.admin().contentType("application/json").body("{\"done\":true}")
                .when().put("/api/admin/feedback/shot-1/done").then().statusCode(200);
        Login.admin().when().get("/api/admin/feedback").then()
                .body("items.find { it.id == 'shot-1' }.done", is(true))
                .body("items.find { it.id == 'shot-1' }.doneBy", is("test-admin"))
                .body("items.find { it.id == 'crash-1' }.done", is(false));

        Login.admin().contentType("application/json").body("{\"done\":false}")
                .when().put("/api/admin/feedback/shot-1/done").then().statusCode(200);
        Login.admin().when().get("/api/admin/feedback").then().body("items.find { it.id == 'shot-1' }.done", is(false));

        Login.admin().when().get("/api/admin/feedback/crash-1/crash-log").then().statusCode(200)
                .body("text", containsString("MapView"));
        Login.admin().contentType("application/json").body("{\"done\":true}")
                .when().put("/api/admin/feedback/..%2Fapps/done").then().statusCode(anyOf(is(400), is(404)));
    }
}
