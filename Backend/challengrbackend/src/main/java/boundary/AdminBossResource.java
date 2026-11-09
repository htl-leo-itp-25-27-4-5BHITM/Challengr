package boundary;

import control.AccountDeletionService;
import control.AdminAudit;
import control.PlayerRepository;
import control.PracticeBot;
import control.RiftBossService;
import entity.CustomSpot;
import entity.Player;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

/**
 * Dashboard → Riss-Wächter: offene Risse sehen und schließen, einen Riss bei einem Spieler öffnen
 * (zum Testen oder als Überraschung für die Tester).
 */
@Path("/api/admin/bosses")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("admin")
public class AdminBossResource {

    /** Spieler, bei dem man einen Riss öffnen kann – ohne Standort (nur der Server kennt ihn). */
    public record Candidate(String id, String name, boolean online, Instant lastSeenAt, String character) {}

    static final int MAX_CANDIDATES = 200;

    @Inject
    RiftBossService bosses;

    @Inject
    PlayerRepository players;

    @Inject
    EntityManager em;

    @Inject
    AdminAudit audit;

    @GET
    public List<RiftBossService.View> open() {
        return bosses.all();
    }

    /** Spieler mit bekanntem Standort: gerade online zuerst, dann zuletzt aktiv. */
    @GET
    @Path("/players")
    @Transactional
    public List<Candidate> candidates() {
        Instant now = Instant.now();
        return em.createQuery("SELECT p FROM Player p WHERE p.lastSeenAt IS NOT NULL", Player.class).getResultList().stream()
                .filter(p -> !PracticeBot.is(p.getId()) && !AccountDeletionService.DELETED_PLAYER_ID.equals(p.getId()))
                .filter(p -> p.getBanUntil() == null || !p.getBanUntil().isAfter(now))
                .filter(p -> p.getLatitude() != 0 || p.getLongitude() != 0)
                .map(p -> new Candidate(p.getId(), p.getName(), GameSocket.isOnline(p.getId()), p.getLastSeenAt(), p.getCharacter()))
                .sorted(Comparator.comparing(Candidate::online).reversed()
                        .thenComparing(Candidate::lastSeenAt, Comparator.reverseOrder()))
                .limit(MAX_CANDIDATES)
                .toList();
    }

    /** Body: {"playerId": "..."} – Riss am nächsten öffentlichen Ort bei diesem Spieler. */
    @POST
    @Path("/spawn")
    @Transactional
    public RiftBossService.View spawnNear(Map<String, String> body) {
        String playerId = body == null ? null : body.get("playerId");
        Player p = playerId == null ? null : players.findById(playerId);
        if (p == null) throw new WebApplicationException("Spieler nicht gefunden", 404);
        if (p.getLatitude() == 0 && p.getLongitude() == 0) throw new WebApplicationException("Von diesem Spieler ist kein Standort bekannt", 409);
        var b = bosses.spawnNear(p);
        audit.log("BOSS_SPAWN", p.getId(), p.getName(), null, b.place, null);
        return bosses.all().stream().filter(v -> v.id() == b.id).findFirst().orElseThrow();
    }

    /** Temporärer Checkpoint fürs Dashboard (Ablaufzeit statt Koordinaten) */
    public record Checkpoint(String id, String name, double latitude, double longitude, Instant expiresAt) {
        static Checkpoint of(CustomSpot c) {
            return new Checkpoint(c.getId(), c.getName(), c.getLatitude(), c.getLongitude(), c.getExpiresAt());
        }
    }

    @GET
    @Path("/checkpoints")
    @Transactional
    public List<Checkpoint> checkpoints() {
        return bosses.checkpoints().stream().map(Checkpoint::of).toList();
    }

    /** Body: {"playerId": "...", "boss": true} – Checkpoint beim Spieler für 30 Minuten, auf Wunsch gleich mit Riss. */
    @POST
    @Path("/checkpoints")
    @Transactional
    public Checkpoint createCheckpoint(Map<String, Object> body) {
        Object id = body == null ? null : body.get("playerId");
        Player p = id == null ? null : players.findById(id.toString());
        if (p == null) throw new WebApplicationException("Spieler nicht gefunden", 404);
        if (p.getLatitude() == 0 && p.getLongitude() == 0) throw new WebApplicationException("Von diesem Spieler ist kein Standort bekannt", 409);
        CustomSpot c = bosses.createCheckpoint(p);
        audit.log("CHECKPOINT_NEW", p.getId(), p.getName(), null, c.getName(), "30 Minuten");
        if (Boolean.TRUE.equals(body.get("boss"))) {
            bosses.spawn(c.getName(), c.getLatitude(), c.getLongitude());
            audit.log("BOSS_SPAWN", p.getId(), p.getName(), null, c.getName(), null);
        }
        return Checkpoint.of(c);
    }

    @DELETE
    @Path("/checkpoints/{id}")
    @Transactional
    public void removeCheckpoint(@PathParam("id") String id) {
        CustomSpot c = em.find(CustomSpot.class, id);
        if (c == null || c.getExpiresAt() == null) throw new NotFoundException();
        c.setActive(false);
        audit.log("CHECKPOINT_END", null, null, c.getName(), null, null);
    }

    @DELETE
    @Path("/{id}")
    @Transactional
    public void close(@PathParam("id") long id) {
        var place = bosses.find(id).map(b -> b.place).orElse(null);
        if (!bosses.close(id)) throw new NotFoundException();
        audit.log("BOSS_CLOSE", null, null, place, null, null);
    }
}
