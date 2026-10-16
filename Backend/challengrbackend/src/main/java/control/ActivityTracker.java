package control;

import entity.PlayerActivity;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import org.jboss.logging.Logger;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Merkt, dass ein Spieler heute aktiv war (ein Datenbank-Eintrag pro Spieler und Tag).
 * Dank Zwischenspeicher im Speicher kostet das nur beim ersten Aufruf des Tages eine Abfrage.
 */
@ApplicationScoped
public class ActivityTracker {

    private static final Logger LOG = Logger.getLogger(ActivityTracker.class);
    /** Tage zählen nach österreichischer Zeit (Schultag) */
    public static final ZoneId ZONE = ZoneId.of("Europe/Vienna");

    private final Map<String, LocalDate> recorded = new ConcurrentHashMap<>();

    @Inject
    EntityManager em;

    public void seen(String playerId) {
        if (playerId == null) return;
        LocalDate today = LocalDate.now(ZONE);
        if (today.equals(recorded.get(playerId))) return;
        try {
            QuarkusTransaction.requiringNew().run(() -> {
                long n = em.createQuery("SELECT COUNT(a) FROM PlayerActivity a WHERE a.playerId = :p AND a.day = :d", Long.class)
                        .setParameter("p", playerId).setParameter("d", today).getSingleResult();
                if (n == 0) em.persist(new PlayerActivity(playerId, today));
            });
            recorded.put(playerId, today);
        } catch (RuntimeException e) {
            // doppelt eingetragen (zwei Anfragen gleichzeitig) oder DB kurz weg – für eine Statistik egal
            LOG.debugf("Aktivität für %s nicht gespeichert: %s", playerId, e.getMessage());
        }
    }

    /** Nach dem Löschen eines Kontos (der Eintrag in der DB wird dort mit gelöscht). */
    public void forget(String playerId) {
        recorded.remove(playerId);
    }
}
