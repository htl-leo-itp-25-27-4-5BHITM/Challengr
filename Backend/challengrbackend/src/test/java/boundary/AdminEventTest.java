package boundary;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.hamcrest.Matchers.*;

/** Events im Dashboard anlegen – die App sieht sie sofort. */
@QuarkusTest
class AdminEventTest {

    @Test
    void createEditShowInAppAndDelete() {
        String id = "ev" + (System.nanoTime() % 1_000_000);
        LocalDate today = control.QuestService.today();
        String body = """
                {"id":"%s","title":"Halloween-Test","subtitle":"Gruselig","start":"%s","end":"%s",
                 "rewardCharacter":null,"rewardCoins":50,
                 "tasks":[{"title":"","metric":"QUIZ_SHOWS","target":2},{"title":"Check ein!","metric":"CHECKINS","target":1}]}
                """.formatted(id, today.minusDays(1), today.plusDays(5));
        Login.admin().contentType("application/json").body(body).when().post("/api/admin/events").then().statusCode(200)
                .body("tasks[0].title", is("2× Quiz-Shows")).body("tasks[0].icon", is("brain.head.profile"));
        Login.admin().contentType("application/json").body(body).when().post("/api/admin/events").then().statusCode(409);
        Login.admin().contentType("application/json").body(body.replace("\"rewardCoins\":50", "\"rewardCoins\":0"))
                .when().put("/api/admin/events/" + id).then().statusCode(400);
        Login.admin().contentType("application/json").body(body.replace("QUIZ_SHOWS", "UNSINN"))
                .when().put("/api/admin/events/" + id).then().statusCode(400);
        Login.admin().contentType("application/json").body(body.replace("Halloween-Test", "Halloween!"))
                .when().put("/api/admin/events/" + id).then().statusCode(200).body("title", is("Halloween!"));

        String p = "ev-player-" + System.nanoTime();
        Login.as(p).contentType("application/json").body("{\"id\":\"" + p + "\",\"name\":\"" + p + "\",\"latitude\":48.3,\"longitude\":14.3}")
                .when().post("/api/players").then().statusCode(200);
        Login.as(p).when().get("/api/quests").then().statusCode(200)
                .body("events.find { it.id == '" + id + "' }.title", is("Halloween!"))
                .body("events.find { it.id == '" + id + "' }.tasks.size()", is(2));

        Login.admin().when().get("/api/admin/events").then().statusCode(200)
                .body("find { it.event.id == '" + id + "' }.state", is("läuft"))
                .body("event.id", hasItem("beta"));
        Login.admin().when().get("/api/admin/events/meta").then().statusCode(200)
                .body("rewardCharacters.id", hasItem("crash-dummy")).body("metrics.size()", is(10));
        Login.admin().when().get("/api/admin/events/" + id + "/progress?fresh=true").then().statusCode(200)
                .body("participants", greaterThanOrEqualTo(1)).body("tasks.size()", is(2));

        Login.admin().when().delete("/api/admin/events/" + id).then().statusCode(204);
        Login.as(p).when().get("/api/quests").then().statusCode(200).body("events.id", not(hasItem(id)));
        Login.as(p).when().get("/api/admin/events").then().statusCode(403);
    }
}
