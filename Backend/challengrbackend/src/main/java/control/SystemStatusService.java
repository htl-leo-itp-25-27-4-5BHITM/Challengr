package control;

import boundary.GameSocket;
import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;

/**
 * Systemstatus fürs Dashboard: Datenbank, verbundene Spieler, Orte (OpenStreetMap/Overpass), Kartenserver der
 * Cartoon-Karte, Keycloak, Backups. Externe Prüfungen laufen parallel mit kurzem Timeout und werden 30 s gemerkt.
 */
@ApplicationScoped
public class SystemStatusService {

    /** state: ok | warn | error | off */
    public record Check(String name, String state, String detail) {}

    public record Status(String checkedAt, String startedAt, long uptimeSeconds, int online, long players,
                         long landmarks, long landmarkTiles, List<Check> checks) {}

    static final Duration TIMEOUT = Duration.ofSeconds(5);
    static final Duration CACHE = Duration.ofSeconds(30);

    @Inject
    EntityManager em;

    @Inject
    LandmarkService landmarks;

    @Inject
    BackupService backups;

    @ConfigProperty(name = "challengr.status.overpass-url", defaultValue = "https://overpass-api.de/api/status")
    String overpassStatusUrl;

    @ConfigProperty(name = "challengr.status.tiles-url", defaultValue = "https://tiles.openfreemap.org/planet")
    String tilesUrl;

    @ConfigProperty(name = "challengr.status.keycloak-url", defaultValue = "${KEYCLOAK_URL:http://localhost:9090}/realms/challengr/.well-known/openid-configuration")
    String keycloakUrl;

    @ConfigProperty(name = "challengr.status.external-checks", defaultValue = "true")
    boolean externalChecks;

    private final HttpClient http = HttpClient.newBuilder().connectTimeout(TIMEOUT).followRedirects(HttpClient.Redirect.NORMAL).build();
    private Instant startedAt = Instant.now();
    private volatile List<Check> externalCache;
    private volatile Instant externalCachedAt;

    void onStart(@Observes StartupEvent e) {
        startedAt = Instant.now();
    }

    @Transactional
    public Status status() {
        List<Check> checks = new ArrayList<>();
        long players = 0, lm = 0, tiles = 0;
        try {
            long t0 = System.nanoTime();
            players = em.createQuery("SELECT COUNT(p) FROM Player p", Long.class).getSingleResult();
            lm = em.createQuery("SELECT COUNT(l) FROM Landmark l", Long.class).getSingleResult();
            tiles = em.createQuery("SELECT COUNT(t) FROM LandmarkTile t", Long.class).getSingleResult();
            long ms = (System.nanoTime() - t0) / 1_000_000;
            checks.add(new Check("Datenbank", ms > 1000 ? "warn" : "ok", "antwortet in " + ms + " ms"));
        } catch (Exception e) {
            checks.add(new Check("Datenbank", "error", e.getMessage()));
        }

        var lh = landmarks.health();
        checks.add(new Check("Orte laden (Hintergrund)", !lh.enabled() ? "off" : lh.failingTiles() > 0 ? "warn" : "ok",
                !lh.enabled() ? "ausgeschaltet"
                        : lh.queued() + " Gebiete in der Warteschlange, " + lh.failingTiles() + " zuletzt fehlgeschlagen"
                        + (lh.lastFetchOk() != null ? ", zuletzt geladen " + lh.lastFetchOk() : "")
                        + (lh.failingTiles() > 0 && lh.lastFetchError() != null ? " – Fehler: " + lh.lastFetchError() : "")));

        boolean pgDump = backups.available();
        Instant last = backups.lastSuccess();
        String backupState = !pgDump ? "error" : backups.lastError() != null ? "warn" : "ok";
        checks.add(new Check("Backups", backupState,
                (pgDump ? "pg_dump bereit" : "pg_dump fehlt im Server")
                        + (last != null ? ", letztes Backup " + last : ", seit dem Start noch keins")
                        + (backups.lastError() != null ? " – Fehler: " + backups.lastError() : "")));

        checks.addAll(external());
        return new Status(Instant.now().toString(), startedAt.toString(), Duration.between(startedAt, Instant.now()).toSeconds(),
                GameSocket.onlineCount(), players, lm, tiles, checks);
    }

    private List<Check> external() {
        if (!externalChecks) return List.of(new Check("Externe Dienste", "off", "Prüfung ausgeschaltet"));
        if (externalCache != null && externalCachedAt.isAfter(Instant.now().minus(CACHE))) return externalCache;
        var overpass = probe("OpenStreetMap (Overpass)", overpassStatusUrl);
        var tiles = probe("Kartenserver Cartoon-Karte (OpenFreeMap)", tilesUrl);
        var keycloak = probe("Login (Keycloak)", keycloakUrl);
        List<Check> result = List.of(overpass.join(), tiles.join(), keycloak.join());
        externalCache = result;
        externalCachedAt = Instant.now();
        return result;
    }

    private CompletableFuture<Check> probe(String name, String url) {
        long t0 = System.nanoTime();
        HttpRequest req = HttpRequest.newBuilder(URI.create(url)).timeout(TIMEOUT)
                .header("User-Agent", "Challengr/1.0 (challengrapp.official@gmail.com)").GET().build();
        return http.sendAsync(req, HttpResponse.BodyHandlers.discarding())
                .thenApply(r -> {
                    long ms = (System.nanoTime() - t0) / 1_000_000;
                    boolean ok = r.statusCode() >= 200 && r.statusCode() < 400;
                    return new Check(name, ok ? (ms > 3000 ? "warn" : "ok") : "error",
                            (ok ? "erreichbar" : "HTTP " + r.statusCode()) + " in " + ms + " ms");
                })
                .exceptionally(e -> new Check(name, "error", "nicht erreichbar: " + e.getClass().getSimpleName()))
                .completeOnTimeout(new Check(name, "error", "keine Antwort in " + TIMEOUT.toSeconds() + " s"),
                        TIMEOUT.toSeconds() + 1, java.util.concurrent.TimeUnit.SECONDS);
    }
}
