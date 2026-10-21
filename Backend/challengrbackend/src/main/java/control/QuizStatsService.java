package control;

import entity.QuizStat;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import org.jboss.logging.Logger;

/** Zählt die Antworten pro Quizfrage – läuft aus dem WebSocket-Timer, daher eigene Transaktion, Fehler nur geloggt. */
@ApplicationScoped
public class QuizStatsService {

    private static final Logger LOG = Logger.getLogger(QuizStatsService.class);

    @Inject
    EntityManager em;

    public void record(long challengeId, int correct, int wrong, int unanswered) {
        try {
            QuarkusTransaction.requiringNew().run(() -> {
                QuizStat s = em.find(QuizStat.class, challengeId, LockModeType.PESSIMISTIC_WRITE);
                if (s == null) {
                    s = new QuizStat(challengeId);
                    em.persist(s);
                }
                s.add(correct, wrong, unanswered);
            });
        } catch (Exception e) {
            LOG.warnf("Quiz-Statistik für Frage %d nicht gespeichert: %s", challengeId, e.getMessage());
        }
    }
}
