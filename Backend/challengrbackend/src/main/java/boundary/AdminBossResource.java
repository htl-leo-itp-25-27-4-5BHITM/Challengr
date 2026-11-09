package boundary;

import control.AccountDeletionService;
import control.AdminAudit;
import control.PlayerRepository;
import control.PracticeBot;
import control.RiftBossService;
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

    @DELETE
    @Path("/{id}")
    @Transactional
    public void close(@PathParam("id") long id) {
        var place = bosses.find(id).map(b -> b.place).orElse(null);
        if (!bosses.close(id)) throw new NotFoundException();
        audit.log("BOSS_CLOSE", null, null, place, null, null);
    }
}
