package control;

import entity.Landmark;
import entity.LandmarkTile;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Check-in-Punkte aus OpenStreetMap. Overpass ist langsam (oft 30 s+), deshalb: Antwort sofort aus dem
 * Zwischenspeicher, fehlende Kacheln lädt ein einzelner Hintergrund-Thread nacheinander (schont Overpass).
 * Geladene Kacheln gelten 30 Tage, fehlgeschlagene werden nach 10 Minuten neu versucht.
 */
@ApplicationScoped
public class LandmarkService {

    private static final Logger LOG = Logger.getLogger(LandmarkService.class);
    static final Duration TILE_MAX_AGE = Duration.ofDays(30);
    static final Duration RETRY_AFTER = Duration.ofMinutes(10);
    /** Spieler sieht Punkte in diesem Umkreis */
    public static final double VISIBLE_RADIUS = 1500;
    public static final int MAX_VISIBLE = 25;

    @ConfigProperty(name = "challengr.landmarks.enabled", defaultValue = "true")
    boolean enabled;

    @ConfigProperty(name = "challengr.landmarks.overpass-url", defaultValue = "https://overpass-api.de/api/interpreter")
    String overpassUrl;

    @Inject
    EntityManager em;

    private final ExecutorService worker = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "landmark-fetch");
        t.setDaemon(true);
        return t;
    });
    private final Set<String> queued = ConcurrentHashMap.newKeySet();
    private final Map<String, Instant> failedAt = new ConcurrentHashMap<>();
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    private volatile Instant lastFetchOk;
    private volatile String lastFetchError;

    /** Für Dashboard → System */
    public record Health(boolean enabled, int queued, int failingTiles, String lastFetchOk, String lastFetchError) {}

    public Health health() {
        Instant cut = Instant.now().minus(RETRY_AFTER);
        int failing = (int) failedAt.values().stream().filter(t -> t.isAfter(cut)).count();
        return new Health(enabled, queued.size(), failing, lastFetchOk == null ? null : lastFetchOk.toString(), lastFetchError);
    }

    @PreDestroy
    void stop() {
        worker.shutdownNow();
    }

    /** Punkte in der Nähe (nächste zuerst); stößt das Laden fehlender Kacheln an. */
    public List<Landmark> near(double latitude, double longitude) {
        List<String> tiles = LandmarkRules.tilesAround(latitude, longitude, VISIBLE_RADIUS);
        ensureLoaded(tiles);
        double dLat = VISIBLE_RADIUS / 111_320.0, dLon = VISIBLE_RADIUS / (111_320.0 * Math.cos(Math.toRadians(latitude)));
        return em.createQuery("""
                        SELECT l FROM Landmark l WHERE l.latitude BETWEEN :s AND :n AND l.longitude BETWEEN :w AND :e
                        """, Landmark.class)
                .setParameter("s", latitude - dLat).setParameter("n", latitude + dLat)
                .setParameter("w", longitude - dLon).setParameter("e", longitude + dLon)
                .getResultList().stream()
                .filter(l -> HotspotCatalog.distanceMeters(latitude, longitude, l.getLatitude(), l.getLongitude()) <= VISIBLE_RADIUS)
                .sorted(Comparator.comparingDouble(l -> HotspotCatalog.distanceMeters(latitude, longitude, l.getLatitude(), l.getLongitude())))
                .limit(MAX_VISIBLE)
                .toList();
    }

    public Optional<Landmark> find(String id) {
        return Optional.ofNullable(em.find(Landmark.class, id));
    }

    private void ensureLoaded(List<String> tiles) {
        if (!enabled) return;
        Instant now = Instant.now();
        for (String key : tiles) {
            LandmarkTile tile = em.find(LandmarkTile.class, key);
            if (tile != null && tile.getFetchedAt().isAfter(now.minus(TILE_MAX_AGE))) continue;
            Instant failed = failedAt.get(key);
            if (failed != null && failed.isAfter(now.minus(RETRY_AFTER))) continue;
            if (queued.add(key)) worker.submit(() -> fetchTile(key));
        }
    }

    /** Eine Kachel aus Overpass laden und ersetzen (läuft im Hintergrund-Thread). */
    void fetchTile(String key) {
        try {
            String body = "data=" + URLEncoder.encode(LandmarkRules.overpassQuery(key), StandardCharsets.UTF_8);
            HttpRequest request = HttpRequest.newBuilder(URI.create(overpassUrl))
                    .timeout(Duration.ofSeconds(90))
                    // Overpass lehnt Anfragen ohne Absender ab (406)
                    .header("User-Agent", "Challengr/1.0 (challengrapp.official@gmail.com)")
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();
            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) throw new IllegalStateException("Overpass HTTP " + response.statusCode());
            store(key, LandmarkRules.parse(response.body()));
            failedAt.remove(key);
            lastFetchOk = Instant.now();
        } catch (Exception e) {
            failedAt.put(key, Instant.now());
            lastFetchError = Instant.now() + ": " + e.getMessage();
            LOG.warnf("Orte für Kachel %s nicht geladen: %s", key, e.getMessage());
        } finally {
            queued.remove(key);
        }
    }

    /** Kachel speichern: alte Punkte der Kachel ersetzen (Check-ins bleiben, die hängen nur an der Id). */
    public void store(String key, List<LandmarkRules.Candidate> candidates) {
        List<double[]> blocked = HotspotCatalog.ALL.stream().map(h -> new double[]{h.latitude(), h.longitude()}).toList();
        List<LandmarkRules.Candidate> chosen = LandmarkRules.select(candidates, blocked);
        QuarkusTransaction.requiringNew().run(() -> {
            em.createQuery("DELETE FROM Landmark l WHERE l.tileKey = :k").setParameter("k", key).executeUpdate();
            for (LandmarkRules.Candidate c : chosen) {
                // Orte, die über die Kachelgrenze ragen (große Parks), kommen evtl. schon aus der Nachbarkachel
                if (em.find(Landmark.class, c.id()) != null) continue;
                em.persist(new Landmark(c.id(), c.name(), c.latitude(), c.longitude(), c.category(), c.radiusMeters(), key));
            }
            LandmarkTile tile = em.find(LandmarkTile.class, key);
            if (tile == null) em.persist(new LandmarkTile(key, Instant.now(), chosen.size()));
            else {
                tile.setFetchedAt(Instant.now());
                tile.setCount(chosen.size());
            }
        });
        LOG.infof("Kachel %s: %d Check-in-Punkte aus %d Orten", key, chosen.size(), candidates.size());
    }
}
