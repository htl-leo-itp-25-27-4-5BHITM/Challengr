package control;

import entity.CharacterProgress;
import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;

import java.util.HashMap;
import java.util.Map;

/**
 * Figuren-Stufen 1–10: Liga-Siege mit einer Figur bringen sie nach oben (Übung und Friendly zählen nicht).
 * Ab Stufe 3 Bronze-, ab 6 Silber-, auf 10 Gold-Aura (zeigt die App).
 */
@ApplicationScoped
public class CharacterLevel {

    /** Siege, ab denen eine Stufe erreicht ist (Index = Stufe - 1) */
    public static final int[] WINS = {0, 1, 3, 6, 10, 15, 21, 28, 36, 45};
    public static final int MAX = WINS.length;
    /** Figur, wenn der Spieler (noch) keine gewählt hat – wie GameCharacter.own in der App */
    public static final String DEFAULT_CHARACTER = "junge";

    public static int level(int wins) {
        int level = 1;
        for (int i = 0; i < WINS.length; i++) if (wins >= WINS[i]) level = i + 1;
        return level;
    }

    /** Siege für die nächste Stufe, -1 auf der höchsten */
    public static int nextLevelWins(int level) {
        return level >= MAX ? -1 : WINS[level];
    }

    @Inject
    EntityManager em;

    /**
     * Liga-Sieg mit der aktuellen Figur zählen.
     * @return neue Stufe, wenn der Sieg eine Stufe höher gebracht hat, sonst 0
     */
    public int addWin(Player winner) {
        String character = characterOf(winner);
        CharacterProgress p = find(winner.getId(), character);
        if (p == null) {
            p = new CharacterProgress(winner.getId(), character);
            em.persist(p);
        }
        int before = level(p.getWins());
        p.setWins(p.getWins() + 1);
        int after = level(p.getWins());
        winner.setCharacterLevel(after);
        return after > before ? after : 0;
    }

    /** Siege pro Figur (nur Figuren mit mindestens einem Sieg) */
    public Map<String, Integer> winsByCharacter(String playerId) {
        Map<String, Integer> wins = new HashMap<>();
        for (CharacterProgress p : em.createQuery("SELECT c FROM CharacterProgress c WHERE c.playerId = :p", CharacterProgress.class)
                .setParameter("p", playerId).getResultList()) {
            wins.put(p.getCharacter(), p.getWins());
        }
        return wins;
    }

    /** Stufe der gerade gewählten Figur neu setzen (nach dem Wechsel der Figur). */
    public void refreshCurrent(Player player) {
        CharacterProgress p = find(player.getId(), characterOf(player));
        player.setCharacterLevel(level(p == null ? 0 : p.getWins()));
    }

    private CharacterProgress find(String playerId, String character) {
        return em.createQuery("SELECT c FROM CharacterProgress c WHERE c.playerId = :p AND c.character = :c", CharacterProgress.class)
                .setParameter("p", playerId).setParameter("c", character)
                .getResultStream().findFirst().orElse(null);
    }

    static String characterOf(Player p) {
        return p.getCharacter() == null ? DEFAULT_CHARACTER : p.getCharacter();
    }
}
