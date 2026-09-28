package boundary;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Messwerte der iPhone-Challenges (Sprint, Lautstärke, Kompass, Kamera, Schütteln, Liegestütze).
 * Hält pro Battle die Werte beider Spieler und entscheidet, wer gewonnen hat.
 */
public class MetricResults {

    public enum Kind {
        SPRINT("sprint", true, 0.0, Tie.DRAW, false),
        LOUDNESS("loudness", true, -60.0, Tie.DRAW, false),
        COMPASS("compass", false, Double.MAX_VALUE, Tie.DRAW, false),
        CAMERA("camera", true, 0.0, Tie.DRAW, false),
        SHAKE("shake", true, 0.0, Tie.DRAW, true),
        PUSHUP("pushup", true, 0.0, Tie.CONFLICT, true);

        /** Name im "metrics"-Block von battle-result. */
        public final String key;
        /** true = höherer Wert gewinnt, false = niedrigerer (Kompass: Abweichung). */
        public final boolean higherWins;
        /** Wert für einen Spieler, der nichts geschickt hat (nach Timeout). */
        public final double missingValue;
        public final Tie onTie;
        /** Ganzzahlig anzeigen (Anzahl Schüttler / Liegestütze). */
        public final boolean integer;

        Kind(String key, boolean higherWins, double missingValue, Tie onTie, boolean integer) {
            this.key = key;
            this.higherWins = higherWins;
            this.missingValue = missingValue;
            this.onTie = onTie;
            this.integer = integer;
        }
    }

    public enum Tie { DRAW, CONFLICT }

    public enum Outcome { FROM_WINS, TO_WINS, DRAW, CONFLICT }

    private record Entry(Kind kind, Map<String, Double> values) {}

    private final Map<Long, Entry> entries = new ConcurrentHashMap<>();

    /**
     * Speichert den Wert eines Spielers (ein späterer Wert desselben Spielers überschreibt nicht).
     *
     * @return true, wenn jetzt beide Spieler einen Wert haben
     */
    public synchronized boolean record(Long battleId, Kind kind, String playerId, double value,
                                       String fromId, String toId) {
        Entry entry = entries.computeIfAbsent(battleId, id -> new Entry(kind, new LinkedHashMap<>()));
        entry.values().putIfAbsent(playerId, value);
        return entry.values().containsKey(fromId) && entry.values().containsKey(toId);
    }

    public synchronized Kind kind(Long battleId) {
        Entry entry = entries.get(battleId);
        return entry == null ? null : entry.kind();
    }

    public synchronized Double value(Long battleId, String playerId) {
        Entry entry = entries.get(battleId);
        return entry == null ? null : entry.values().get(playerId);
    }

    public synchronized void clear(Long battleId) {
        entries.remove(battleId);
    }

    /** Entscheidet anhand der gespeicherten Werte (fehlende Werte zählen als missingValue). */
    public synchronized Outcome decide(Long battleId, String fromId, String toId) {
        Entry entry = entries.get(battleId);
        if (entry == null) return Outcome.DRAW;
        Kind kind = entry.kind();
        double from = entry.values().getOrDefault(fromId, kind.missingValue);
        double to   = entry.values().getOrDefault(toId, kind.missingValue);
        return decide(kind, from, to);
    }

    static Outcome decide(Kind kind, double from, double to) {
        if (Double.compare(from, to) == 0) {
            return kind.onTie == Tie.CONFLICT ? Outcome.CONFLICT : Outcome.DRAW;
        }
        boolean fromBetter = kind.higherWins ? from > to : from < to;
        return fromBetter ? Outcome.FROM_WINS : Outcome.TO_WINS;
    }
}
