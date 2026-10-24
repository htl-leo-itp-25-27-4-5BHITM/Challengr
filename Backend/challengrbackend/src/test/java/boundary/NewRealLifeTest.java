package boundary;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/** Länder-Kompass, Reaktions-Test, Zeitgefühl: in der Datenbank und richtig ausgewertet. */
@QuarkusTest
class NewRealLifeTest {

    @Test
    void newChallengesExistInTheIphoneCategory() {
        Login.admin().when().get("/api/challenges").then().statusCode(200)
                .body("text", hasItems(
                        "Länder-Kompass: Zeig in die Richtung des Landes – wer genauer zeigt, gewinnt.",
                        "Reaktions-Test: Tippe sofort, wenn der Bildschirm grün wird.",
                        "Zeitgefühl: Stoppe genau nach der Zielzeit – ohne Uhr."));
    }

    @Test
    void lowerWinsAndImpossibleValuesAreCapped() {
        for (var k : new MetricResults.Kind[]{MetricResults.Kind.COUNTRY, MetricResults.Kind.REACTION, MetricResults.Kind.TIMING}) {
            assertEquals(MetricResults.Outcome.FROM_WINS, MetricResults.decide(k, 120, 300));
            assertEquals(MetricResults.Outcome.DRAW, MetricResults.decide(k, 300, 300));
        }
        assertEquals(100, MetricResults.clamp(MetricResults.Kind.REACTION, 3));     // 3 ms = geschummelt
        assertEquals(180, MetricResults.clamp(MetricResults.Kind.COUNTRY, 999));
        assertEquals(0, MetricResults.clamp(MetricResults.Kind.TIMING, -50));
        assertEquals(MetricResults.Kind.REACTION.missingValue, MetricResults.clamp(MetricResults.Kind.REACTION, Double.NaN));
        // wer nichts schickt, verliert
        assertEquals(MetricResults.Outcome.FROM_WINS,
                MetricResults.decide(MetricResults.Kind.TIMING, 900, MetricResults.Kind.TIMING.missingValue));
    }
}
