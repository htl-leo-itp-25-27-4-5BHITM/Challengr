package control;

import entity.Player;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;

/**
 * Kopfgeld – die Jagd auf den König.
 * Immer höchstens ein Spieler trägt es: anfangs Platz 1 der Rangliste. Wer ihn in der Liga besiegt,
 * kassiert Bonus-Trophäen und trägt ab dann selbst das Kopfgeld. Ist der Träger einen Tag nicht aktiv,
 * geht es an den aktuellen Platz 1 (unter den Aktiven).
 */
@ApplicationScoped
public class BountyService {

    /** Bonus-Trophäen für den, der den Träger besiegt. */
    public static final int BONUS = 30;
    /** So lange darf der Träger weg sein, dann wandert das Kopfgeld weiter. */
    static final Duration IDLE = Duration.ofHours(24);

    @Inject
    EntityManager em;

    @Inject
    PushService push;

    @Scheduled(every = "5m", delayed = "1m", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void scheduled() {
        refresh();
    }

    /** Prüft den Träger und vergibt das Kopfgeld neu, wenn nötig. Gibt den Träger zurück (null = niemand). */
    @Transactional
    public Player refresh() {
        Instant now = Instant.now();
        List<Player> holders = em.createQuery("SELECT p FROM Player p WHERE p.bountySince IS NOT NULL", Player.class)
                .getResultList();
        Player holder = null;
        for (Player p : holders) {
            if (holder == null && canHold(p, now)) holder = p;
            else p.setBountySince(null);   // mehr als einer oder nicht (mehr) berechtigt
        }
        if (holder != null) return holder;

        Player top = em.createQuery("SELECT p FROM Player p WHERE p.trophies > 0", Player.class).getResultList().stream()
                .filter(p -> canHold(p, now))
                .max(Comparator.comparingInt(Player::getTrophies)
                        .thenComparingInt(Player::getHighestTrophies)
                        .thenComparing(p -> p.getName() == null ? "" : p.getName(), Comparator.reverseOrder()))
                .orElse(null);
        if (top != null) {
            top.setBountySince(now);
            push.bountyOnYou(top.getId());
        }
        return top;
    }

    /**
     * Liga-Sieg über den Träger: das Kopfgeld wechselt zum Sieger.
     * @return Bonus-Trophäen für den Sieger (0, wenn der Verlierer kein Kopfgeld hatte)
     */
    public int claimIfHolder(Player winner, Player loser) {
        if (!loser.hasBounty() || PracticeBot.is(winner.getId())) return 0;
        loser.setBountySince(null);
        winner.setBountySince(Instant.now());
        winner.setBountiesClaimed(winner.getBountiesClaimed() + 1);
        push.bountyLost(loser.getId(), winner.getId());
        return BONUS;
    }

    static boolean canHold(Player p, Instant now) {
        return !AccountDeletionService.DELETED_PLAYER_ID.equals(p.getId())
                && !PracticeBot.is(p.getId())
                && (p.getBanUntil() == null || !p.getBanUntil().isAfter(now))
                && p.getLastSeenAt() != null && p.getLastSeenAt().plus(IDLE).isAfter(now);
    }
}
