package control;

import entity.ChallengeCategory;
import entity.Challenges;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.*;

/** Wissensfragen aus quiz-questions.txt: Datei sauber, Abgleich beim Start, nichts doppelt. */
@QuarkusTest
class QuizQuestionSyncTest {

    @Inject
    QuizQuestionSync sync;

    private final List<QuizQuestionSync.Question> questions = QuizQuestionSync.parse(QuizQuestionSync.readFile());

    @Test
    void fileHasAtLeast200CleanQuestions() {
        assertTrue(questions.size() >= 200, "nur " + questions.size() + " Fragen");
        Set<String> texts = new HashSet<>();
        for (var q : questions) {
            assertTrue(texts.add(q.text()), "doppelt: " + q.text());
            assertTrue(q.text().endsWith("?"), "keine Frage: " + q.text());
            Set<String> options = new HashSet<>(q.wrong());
            options.add(q.correct());
            assertEquals(4, options.size(), "Antworten nicht verschieden: " + q.text());
            options.forEach(o -> assertFalse(o.isBlank(), "leere Antwort: " + q.text()));
        }
    }

    @Test
    void answersAreShuffledButTheCorrectOneIsMarked() {
        Set<Integer> positions = new HashSet<>();
        for (var q : questions) {
            Challenges c = QuizQuestionSync.toChallenge(q, new ChallengeCategory());
            List<String> options = List.of(c.getOptionA(), c.getOptionB(), c.getOptionC(), c.getOptionD());
            assertEquals(q.correct(), options.get(c.getCorrectIndex()), q.text());
            positions.add(c.getCorrectIndex());
        }
        assertEquals(Set.of(0, 1, 2, 3), positions, "richtige Antwort steht nicht immer an derselben Stelle");
    }

    @Test
    void allQuestionsAreInTheDatabaseAndSyncIsIdempotent() {
        List<String> texts = given().when().get("/api/challenges/Wissen").then().statusCode(200)
                .extract().jsonPath().getList("text");
        for (var q : questions) {
            assertTrue(texts.contains(q.text()), "fehlt in der DB: " + q.text());
        }
        assertEquals(texts.size(), new HashSet<>(texts).size(), "Fragen doppelt in der DB");
        assertEquals(0, sync.sync(), "zweiter Abgleich legt nichts an");
    }

    @Test
    void parserRejectsBrokenLines() {
        assertThrows(IllegalStateException.class, () -> QuizQuestionSync.parse("Frage? | a | b | c"));
        assertEquals(0, QuizQuestionSync.parse("# Kommentar\n\n").size());
    }

    @Test
    void historyPrefersQuestionsNobodyHadRecently() {
        QuizHistory history = new QuizHistory();
        List<Challenges> pool = new java.util.ArrayList<>();
        for (int i = 1; i <= 8; i++) {
            Challenges c = new Challenges("F" + i, null);
            c.setId(i);
            pool.add(c);
        }
        history.remember(pool.subList(0, 4), "a");   // A hatte 1–4
        history.remember(pool.subList(4, 6), "b");   // B hatte 5–6
        List<Challenges> order = history.freshFirst(pool, new Random(1), "a", "b");
        assertEquals(Set.of(7L, 8L), Set.of(order.get(0).getId(), order.get(1).getId()), "7 und 8 hatte keiner");
        assertEquals(8, order.size(), "die anderen bleiben als Reserve");
    }
}
