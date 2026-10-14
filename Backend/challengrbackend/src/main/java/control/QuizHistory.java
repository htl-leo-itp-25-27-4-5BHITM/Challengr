package control;

import entity.Challenges;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Merkt sich pro Spieler die zuletzt gestellten Quiz-Fragen, damit nicht dauernd dieselben kommen.
 * Nur im Speicher – nach einem Neustart fängt es von vorn an, das reicht für Abwechslung.
 */
@ApplicationScoped
public class QuizHistory {

    /** So viele Fragen pro Spieler merken (bei 4 Fragen pro Quiz: die letzten 25 Quiz-Shows). */
    static final int REMEMBER = 100;

    private final Map<String, Deque<Long>> recent = new ConcurrentHashMap<>();

    /** Gemischt, Fragen, die keiner der Spieler zuletzt hatte, zuerst. */
    public List<Challenges> freshFirst(Collection<Challenges> pool, Random random, String... playerIds) {
        List<Challenges> fresh = new ArrayList<>();
        List<Challenges> seen = new ArrayList<>();
        for (Challenges c : pool) {
            (seenByAny(c.getId(), playerIds) ? seen : fresh).add(c);
        }
        Collections.shuffle(fresh, random);
        Collections.shuffle(seen, random);
        fresh.addAll(seen);
        return fresh;
    }

    public void remember(Collection<Challenges> questions, String... playerIds) {
        for (String id : playerIds) {
            if (id == null) continue;
            Deque<Long> list = recent.computeIfAbsent(id, k -> new ArrayDeque<>());
            synchronized (list) {
                questions.forEach(q -> list.addLast(q.getId()));
                while (list.size() > REMEMBER) list.removeFirst();
            }
        }
    }

    private boolean seenByAny(long questionId, String... playerIds) {
        for (String id : playerIds) {
            Deque<Long> list = id == null ? null : recent.get(id);
            if (list != null) {
                synchronized (list) {
                    if (list.contains(questionId)) return true;
                }
            }
        }
        return false;
    }
}
