package control;

/**
 * Trophäen-Gewinn und -Verlust in der Liga, abhängig vom Trophäen-Abstand der beiden Spieler.
 * Gleich stark: +30 / -20. Pro 25 Trophäen, die der Verlierer mehr hatte, gibt es 1 mehr
 * (Außenseiter-Sieg lohnt sich, Favoriten-Sieg bringt weniger) – begrenzt, damit ein Battle nie alles entscheidet.
 */
public final class TrophyMath {

    public static final int BASE_WIN = 30;
    public static final int BASE_LOSS = 20;
    static final int TROPHIES_PER_STEP = 25;

    public record Result(int winnerDelta, int loserDelta) {}

    private TrophyMath() {}

    public static Result delta(int winnerTrophies, int loserTrophies) {
        int shift = Math.round((loserTrophies - winnerTrophies) / (float) TROPHIES_PER_STEP);
        int win = clamp(BASE_WIN + shift, 10, 50);
        int loss = clamp(BASE_LOSS + shift, 5, 40);
        // Trophäen nie unter 0
        return new Result(win, -Math.min(loss, Math.max(loserTrophies, 0)));
    }

    private static int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }
}
