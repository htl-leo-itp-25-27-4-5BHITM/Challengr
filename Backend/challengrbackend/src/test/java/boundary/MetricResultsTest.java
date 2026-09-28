package boundary;

import org.junit.jupiter.api.Test;

import static boundary.MetricResults.Kind.*;
import static boundary.MetricResults.Outcome.*;
import static org.junit.jupiter.api.Assertions.*;

class MetricResultsTest {

    @Test
    void waitsForBothPlayers() {
        MetricResults results = new MetricResults();

        assertFalse(results.record(1L, SPRINT, "a", 12.0, "a", "b"), "Nach dem ersten Wert noch nicht auswerten");
        assertTrue(results.record(1L, SPRINT, "b", 8.0, "a", "b"));
        assertEquals(FROM_WINS, results.decide(1L, "a", "b"));
    }

    @Test
    void firstValueOfAPlayerCounts() {
        MetricResults results = new MetricResults();

        results.record(1L, SHAKE, "a", 10, "a", "b");
        results.record(1L, SHAKE, "a", 99, "a", "b"); // doppelt geschickt

        assertEquals(10.0, results.value(1L, "a"));
    }

    @Test
    void missingPlayerLosesAfterTimeout() {
        MetricResults results = new MetricResults();
        results.record(1L, LOUDNESS, "b", -20.0, "a", "b");

        assertEquals(TO_WINS, results.decide(1L, "a", "b"));
    }

    @Test
    void compassLowerDeviationWins() {
        assertEquals(FROM_WINS, MetricResults.decide(COMPASS, 5, 40));
        assertEquals(TO_WINS, MetricResults.decide(COMPASS, 40, 5));
    }

    @Test
    void compassMissingPlayerLoses() {
        MetricResults results = new MetricResults();
        results.record(1L, COMPASS, "a", 170.0, "a", "b");

        assertEquals(FROM_WINS, results.decide(1L, "a", "b"));
    }

    @Test
    void tiesFollowTheRules() {
        assertEquals(DRAW, MetricResults.decide(SPRINT, 10, 10));
        assertEquals(CONFLICT, MetricResults.decide(PUSHUP, 20, 20), "Liegestütz-Gleichstand = Konflikt wie bisher");
    }

    @Test
    void clearRemovesBattle() {
        MetricResults results = new MetricResults();
        results.record(1L, CAMERA, "a", 0.5, "a", "b");
        results.clear(1L);

        assertNull(results.kind(1L));
    }
}
