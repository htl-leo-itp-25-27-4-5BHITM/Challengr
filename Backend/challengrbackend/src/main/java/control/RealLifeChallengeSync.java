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

import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Neue gemessene Real-Life-Challenges in bestehende Datenbanken bringen (reference-data.sql läuft nur bei leerer DB).
 * Die App erkennt die Challenge am Textanfang (BattleScreen.forChallenge) – Texte hier nicht umformulieren.
 */
@ApplicationScoped
public class RealLifeChallengeSync {

    private static final Logger LOG = Logger.getLogger(RealLifeChallengeSync.class);

    static final List<String> TEXTS = List.of(
            "Länder-Kompass: Zeig in die Richtung des Landes – wer genauer zeigt, gewinnt.",
            "Reaktions-Test: Tippe sofort, wenn der Bildschirm grün wird.",
            "Zeitgefühl: Stoppe genau nach der Zielzeit – ohne Uhr."
    );

    @Inject
    EntityManager em;

    @Inject
    ChallengeCategoriesRepository categories;

    void onStart(@Observes @Priority(Interceptor.Priority.APPLICATION + 650) StartupEvent e) {
        sync();
    }

    @Transactional
    public int sync() {
        ChallengeCategory iphone = categories.findByName(BattleMode.REALLIFE_CATEGORY);
        if (iphone == null) return 0;
        Set<String> existing = new HashSet<>(em.createQuery(
                "SELECT c.text FROM Challenges c WHERE c.challengeCategory = :k", String.class).setParameter("k", iphone).getResultList());
        int added = 0;
        for (String text : TEXTS) {
            if (existing.add(text)) {
                em.persist(new Challenges(text, iphone));
                added++;
            }
        }
        if (added > 0) LOG.infof("Neue Real-Life-Challenges angelegt: %d", added);
        return added;
    }
}
