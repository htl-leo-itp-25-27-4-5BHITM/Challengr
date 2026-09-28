package boundary;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Sammelt die Votes pro Battle – genau eine Stimme pro Spieler.
 * Ein zweiter Vote desselben Spielers (Doppelklick, doppelt gesendete Nachricht)
 * wird ignoriert, damit ein Spieler das Battle nicht allein entscheiden kann.
 */
public class BattleVotes {

    // battleId -> (playerId -> winnerName), Reihenfolge der Abgabe bleibt erhalten
    private final Map<Long, Map<String, String>> votes = new ConcurrentHashMap<>();

    /**
     * Registriert einen Vote.
     *
     * @return beide Votes (in Abgabe-Reihenfolge), sobald zwei verschiedene Spieler
     *         abgestimmt haben – sonst null. Danach ist das Battle zurückgesetzt.
     */
    public synchronized List<String> register(Long battleId, String playerId, String winnerName) {
        if (battleId == null || playerId == null || winnerName == null) {
            return null;
        }

        Map<String, String> byPlayer = votes.computeIfAbsent(battleId, id -> new LinkedHashMap<>());
        if (byPlayer.containsKey(playerId)) {
            return null;
        }
        byPlayer.put(playerId, winnerName);

        if (byPlayer.size() < 2) {
            return null;
        }

        votes.remove(battleId);
        return new ArrayList<>(byPlayer.values());
    }

    public synchronized void clear(Long battleId) {
        votes.remove(battleId);
    }

    public synchronized int count(Long battleId) {
        Map<String, String> byPlayer = votes.get(battleId);
        return byPlayer == null ? 0 : byPlayer.size();
    }
}
