package control;

import entity.ChallengeCategory;
import entity.Challenges;
import io.quarkus.runtime.StartupEvent;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import jakarta.interceptor.Interceptor;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import org.jboss.logging.Logger;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;

/**
 * Bringt die Wissensfragen aus {@code quiz-questions.txt} in die Datenbank: legt beim Start jede Frage an,
 * die es (am Text erkannt) noch nicht gibt. Bestehende Fragen bleiben unverändert – neue Fragen gehen also
 * mit jedem Deploy live, ohne Daten zu löschen. Läuft nach dem {@link ReferenceDataSeeder}.
 */
@ApplicationScoped
public class QuizQuestionSync {

    private static final Logger LOG = Logger.getLogger(QuizQuestionSync.class);
    static final String FILE = "quiz-questions.txt";

    public record Question(String text, String correct, List<String> wrong) {}

    @Inject
    EntityManager em;

    @Inject
    ChallengeCategoriesRepository categories;

    void onStart(@Observes @Priority(Interceptor.Priority.APPLICATION + 600) StartupEvent event) {
        sync();
    }

    /** @return Anzahl neu angelegter Fragen. */
    @Transactional
    public int sync() {
        ChallengeCategory wissen = categories.findByName(BattleMode.KNOWLEDGE_CATEGORY);
        if (wissen == null) {
            LOG.warn("Kategorie Wissen fehlt – Quiz-Fragen nicht abgeglichen");
            return 0;
        }
        Set<String> existing = new HashSet<>(em.createQuery(
                        "SELECT c.text FROM Challenges c WHERE c.challengeCategory = :k", String.class)
                .setParameter("k", wissen).getResultList());
        // im Dashboard umformulierte Fragen nicht unter dem alten Text neu anlegen
        existing.addAll(em.createQuery(
                        "SELECT c.originalText FROM Challenges c WHERE c.challengeCategory = :k AND c.originalText IS NOT NULL", String.class)
                .setParameter("k", wissen).getResultList());
        int added = 0;
        for (Question q : parse(readFile())) {
            if (existing.add(q.text())) {
                em.persist(toChallenge(q, wissen));
                added++;
            }
        }
        LOG.infof("Quiz-Fragen abgeglichen: %d neu, %d insgesamt", added, existing.size());
        return added;
    }

    /** Antworten gemischt – immer gleich pro Frage, damit die richtige nicht immer an derselben Stelle steht. */
    static Challenges toChallenge(Question q, ChallengeCategory category) {
        List<String> options = new ArrayList<>(q.wrong());
        options.add(q.correct());
        Collections.shuffle(options, new Random(q.text().hashCode()));
        Challenges c = new Challenges(q.text(), category);
        c.setOptionA(options.get(0));
        c.setOptionB(options.get(1));
        c.setOptionC(options.get(2));
        c.setOptionD(options.get(3));
        c.setCorrectIndex(options.indexOf(q.correct()));
        return c;
    }

    /** Eine Frage pro Zeile: {@code Frage | richtig | falsch | falsch | falsch}; # = Kommentar. */
    static List<Question> parse(String content) {
        List<Question> result = new ArrayList<>();
        for (String line : content.split("\n")) {
            String trimmed = line.trim();
            if (trimmed.isEmpty() || trimmed.startsWith("#")) continue;
            String[] parts = trimmed.split("\\|");
            if (parts.length != 5) {
                throw new IllegalStateException(FILE + ": erwartet 5 Teile, gefunden " + parts.length + " in: " + trimmed);
            }
            List<String> p = java.util.Arrays.stream(parts).map(String::trim).toList();
            result.add(new Question(p.get(0), p.get(1), p.subList(2, 5)));
        }
        return result;
    }

    static String readFile() {
        try (InputStream in = QuizQuestionSync.class.getClassLoader().getResourceAsStream(FILE)) {
            if (in == null) throw new IllegalStateException(FILE + " fehlt");
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new IllegalStateException(FILE + " nicht lesbar", e);
        }
    }
}
