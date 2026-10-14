package control;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/** Trophäen hängen vom Trophäen-Abstand ab, nicht von Rang-Grenzen. */
class TrophyMathTest {

    @Test
    void equalPlayersGetTheBaseValues() {
        assertEquals(new TrophyMath.Result(30, -20), TrophyMath.delta(500, 500));
    }

    @Test
    void underdogWinsMoreAndFavouriteLosesMore() {
        var r = TrophyMath.delta(400, 600); // 200 Abstand → 8 Stufen
        assertEquals(38, r.winnerDelta());
        assertEquals(-28, r.loserDelta());
    }

    @Test
    void favouriteWinsLessAndUnderdogLosesLess() {
        var r = TrophyMath.delta(600, 400);
        assertEquals(22, r.winnerDelta());
        assertEquals(-12, r.loserDelta());
    }

    @Test
    void neighboursAcrossARankBorderAreTreatedLikeEquals() {
        // früher: 349 vs. 350 zählte als ganzer Rang Unterschied, 200 vs. 349 als keiner
        assertEquals(TrophyMath.delta(349, 350), TrophyMath.delta(500, 500));
    }

    @Test
    void deltasAreCappedAndNeverBelowZero() {
        var huge = TrophyMath.delta(0, 5000);
        assertEquals(50, huge.winnerDelta());
        assertEquals(-40, huge.loserDelta());

        var tiny = TrophyMath.delta(5000, 0);
        assertEquals(10, tiny.winnerDelta());
        assertEquals(0, tiny.loserDelta(), "wer 0 hat, verliert nichts mehr");

        assertEquals(-7, TrophyMath.delta(100, 7).loserDelta());
    }
}
