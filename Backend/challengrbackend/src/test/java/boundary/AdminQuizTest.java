package boundary;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import java.util.List;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/** Quizfragen im Dashboard und „Frage melden“ aus der App. */
@QuarkusTest
class AdminQuizTest {

    private static String body(String text, String... choices) {
        return "{\"text\":\"" + text + "\",\"choices\":[\"" + String.join("\",\"", choices) + "\"],\"correctIndex\":1}";
    }

    @Test
    void createEditDeactivateAndReport() {
        String text = "Testfrage " + System.nanoTime() + "?";
        long id = ((Number) Login.admin().contentType("application/json").body(body(text, "A", "B", "C", "D"))
                .when().post("/api/admin/quiz/questions").then().statusCode(200)
                .body("correctIndex", is(1)).body("active", is(true)).extract().path("id")).longValue();
        // doppelt / ungültig
        Login.admin().contentType("application/json").body(body(text, "A", "B", "C", "D"))
                .when().post("/api/admin/quiz/questions").then().statusCode(409);
        Login.admin().contentType("application/json").body(body("Kurz", "A", "A", "C", "D"))
                .when().post("/api/admin/quiz/questions").then().statusCode(400);

        // bearbeiten merkt sich den alten Text
        Login.admin().contentType("application/json").body(body(text + " (neu)", "A", "B2", "C", "D"))
                .when().put("/api/admin/quiz/questions/" + id).then().statusCode(200)
                .body("edited", is(true)).body("choices[1]", is("B2"));

        // Spieler meldet die Frage – zweimal zählt einmal
        String p = "quizrep-" + System.nanoTime();
        Login.as(p).contentType("application/json").body("{\"id\":\"" + p + "\",\"name\":\"" + p + "\",\"latitude\":48.3,\"longitude\":14.3}")
                .when().post("/api/players").then().statusCode(200);
        for (int i = 0; i < 2; i++) {
            Login.as(p).contentType("application/json").body("{\"reason\":\"FALSCHE_ANTWORT\",\"comment\":\"B ist falsch\"}")
                    .when().post("/api/quiz/questions/" + id + "/report").then().statusCode(204);
        }
        Login.as(p).contentType("application/json").body("{\"reason\":\"QUATSCH\"}")
                .when().post("/api/quiz/questions/" + id + "/report").then().statusCode(400);
        given().contentType("application/json").body("{}").when().post("/api/quiz/questions/" + id + "/report").then().statusCode(401);

        Login.admin().when().get("/api/admin/quiz/questions?filter=reported").then().statusCode(200)
                .body("find { it.id == " + id + " }.openReports", is(1));
        Login.admin().when().get("/api/admin/quiz/reports").then().statusCode(200)
                .body("find { it.questionId == " + id + " }.reason", is("FALSCHE_ANTWORT"))
                .body("find { it.questionId == " + id + " }.playerName", is(p));
        Login.admin().when().post("/api/admin/quiz/questions/" + id + "/reports/resolve").then().statusCode(200)
                .body("openReports", is(0));

        // deaktivieren
        Login.admin().contentType("application/json").body("{\"active\":false}")
                .when().put("/api/admin/quiz/questions/" + id + "/active").then().statusCode(200).body("active", is(false));
        Login.admin().when().get("/api/admin/quiz/questions?filter=inactive").then().statusCode(200).body("id", hasItem((int) id));
        Login.admin().when().get("/api/admin/audit").then().statusCode(200).body("action", hasItems("QUIZ_NEW", "QUIZ_EDIT", "QUIZ_OFF"));

        Login.as(p).when().get("/api/admin/quiz/questions").then().statusCode(403);
    }

    @Test
    void hardQuestionsAreFlagged() {
        var stat = new entity.QuizStat(1L);
        stat.add(1, 9, 2);
        var c = new entity.Challenges("x", null);
        c.setOptionA("a"); c.setOptionB("b"); c.setOptionC("c"); c.setOptionD("d"); c.setCorrectIndex(0);
        var dto = AdminQuizResource.toDTO(c, stat, 0);
        org.junit.jupiter.api.Assertions.assertTrue(dto.hard());
        org.junit.jupiter.api.Assertions.assertEquals(12, dto.answers());
        var few = new entity.QuizStat(2L);
        few.add(0, 3, 0);
        org.junit.jupiter.api.Assertions.assertFalse(AdminQuizResource.toDTO(c, few, 0).hard(), "zu wenige Antworten");
        org.junit.jupiter.api.Assertions.assertEquals(List.of("a", "b", "c", "d"), dto.choices());
    }
}
