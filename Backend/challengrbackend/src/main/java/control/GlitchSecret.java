package control;

import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

/**
 * Geheime Figur Glitch – nirgends angekündigt.
 * Wer drei Quiz-Shows in Folge gegen den Trainings-Dummy mit 0 Punkten beendet, lässt Glitch aus dem Dummy ausbrechen.
 */
@ApplicationScoped
public class GlitchSecret {

    public static final String ID = "glitch";
    static final int STREAK = 3;

    @Inject
    EntityManager em;

    /**
     * Eine fertig gespielte Übungs-Quiz-Show zählen.
     * @return true, wenn Glitch genau jetzt freigeschaltet wurde
     */
    @Transactional
    public boolean recordPracticeQuiz(String playerId, int score) {
        Player p = em.find(Player.class, playerId);
        if (p == null || p.isGlitchUnlocked()) return false;
        if (score > 0) {
            p.setGlitchStreak(0);
            return false;
        }
        p.setGlitchStreak(p.getGlitchStreak() + 1);
        if (p.getGlitchStreak() < STREAK) return false;
        p.setGlitchUnlocked(true);
        return true;
    }
}
