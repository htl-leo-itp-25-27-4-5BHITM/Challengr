package control;

import entity.Battle;
import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.util.List;
import java.util.Random;

/**
 * Übungsgegner "Trainings-Dummy": nimmt jede Herausforderung an und spielt Quiz-Show und Real-Life mit.
 * Für neue Spieler ohne Gegner in der Nähe und für den App-Store-Prüfer (B5).
 * Übungs-Battles zählen nirgends: keine Trophäen, Sticker, Aufgaben, Ranglisten oder Verlauf.
 */
@ApplicationScoped
public class PracticeBot {

    public static final String ID = "practice-bot";
    public static final String NAME = "Trainings-Dummy";
    public static final String CHARACTER = "crash-dummy";

    /** So oft liegt der Bot in der Quiz-Show richtig. */
    static final double QUIZ_CORRECT_CHANCE = 0.55;
    /** Emojis, mit denen der Bot auf Emotes antwortet (müssen in GameSocket.EMOTES stehen). */
    public static final List<String> REPLIES = List.of("😎", "🔥", "😤", "😅", "🤝", "👀", "💪");

    @Inject
    EntityManager em;

    public static boolean is(String playerId) {
        return ID.equals(playerId);
    }

    public static boolean isPractice(Battle battle) {
        return battle != null && (is(battle.getFromPlayer().getId()) || is(battle.getToPlayer().getId()));
    }

    /** Legt den Bot beim ersten Übungs-Battle an. */
    @Transactional
    public Player ensure() {
        Player bot = em.find(Player.class, ID);
        if (bot == null) {
            bot = new Player(NAME, 0, 0);
            bot.setId(ID);
            bot.setCharacter(CHARACTER);
            bot.setInvisible(true);
            em.persist(bot);
        }
        return bot;
    }

    /** Antwort in einer Quiz-Runde: welcher Knopf und nach wie vielen Millisekunden. */
    public record QuizMove(int answerIndex, long delayMs) {}

    public static QuizMove quizMove(int correctIndex, long roundMs, Random random) {
        int index = correctIndex;
        if (correctIndex < 0 || random.nextDouble() >= QUIZ_CORRECT_CHANCE) {
            index = (Math.max(correctIndex, 0) + 1 + random.nextInt(3)) % 4; // eine der drei falschen
        }
        // zwischen 25 % und 75 % der Rundenzeit nachdenken
        long delay = (long) (roundMs * (0.25 + 0.5 * random.nextDouble()));
        return new QuizMove(index, delay);
    }

    /**
     * Messwert des Bots: knapp um den des Spielers, mal besser, mal schlechter (etwa halbe-halbe).
     * Nie negativ, außer der Wert des Spielers ist es (Lautstärke in dB).
     */
    public static double metricValue(double playerValue, boolean integer, Random random) {
        double spread = Math.max(Math.abs(playerValue) * 0.25, 1);
        double value = playerValue + spread * (2 * random.nextDouble() - 1);
        if (playerValue >= 0) value = Math.max(0, value);
        return integer ? Math.round(value) : value;
    }
}
