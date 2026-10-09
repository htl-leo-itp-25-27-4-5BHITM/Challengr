package control;

import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

/**
 * B4: Konten, die sehr lange nicht aktiv waren, werden gelöscht (wie "Konto löschen").
 * Die Frist steht in der Datenschutzerklärung. Spieler ohne Aktivitätsdatum (vor dieser Funktion
 * angelegt) werden nicht angefasst, bis sie wieder aktiv waren.
 */
@ApplicationScoped
public class InactiveAccountCleanup {

    private static final Logger LOG = Logger.getLogger(InactiveAccountCleanup.class);

    @ConfigProperty(name = "challengr.retention.inactive-days", defaultValue = "365")
    int inactiveDays;

    @Inject
    EntityManager em;

    @Inject
    AccountDeletionService accountDeletion;

    @Scheduled(every = "24h", delayed = "10m")
    void scheduled() {
        int deleted = run(Instant.now());
        if (deleted > 0) LOG.infof("%d inaktive Konten gelöscht (älter als %d Tage)", deleted, inactiveDays);
    }

    /** @return Anzahl gelöschter Konten */
    public int run(Instant now) {
        Instant cutoff = now.minus(Duration.ofDays(inactiveDays));
        List<String> ids = em.createQuery(
                        "SELECT p.id FROM Player p WHERE p.lastSeenAt IS NOT NULL AND p.lastSeenAt < :cutoff AND p.id <> :placeholder",
                        String.class)
                .setParameter("cutoff", cutoff)
                .setParameter("placeholder", AccountDeletionService.DELETED_PLAYER_ID)
                .getResultList();
        int count = 0;
        for (String id : ids) {
            try {
                accountDeletion.deleteAccount(id);
                count++;
            } catch (Exception e) {
                LOG.warnf("Inaktives Konto %s konnte nicht gelöscht werden: %s", id, e.getMessage());
            }
        }
        return count;
    }
}
