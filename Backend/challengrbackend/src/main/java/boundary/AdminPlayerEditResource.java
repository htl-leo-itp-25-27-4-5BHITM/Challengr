package boundary;

import control.AdminAudit;
import entity.AdminAuditEntry;
import entity.Player;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

/** Trophäen und Coins eines Spielers korrigieren – mit Pflicht-Grund, alles landet im Protokoll. */
@Path("/api/admin")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("admin")
public class AdminPlayerEditResource {

    static final int MAX_VALUE = 100_000;

    /** null = nicht ändern. resetRecord: Rekord (höchster Stand) auf die neuen Trophäen setzen. */
    public record AdjustRequest(Integer trophies, Integer coins, Boolean resetRecord, String reason) {}

    public record AdjustResult(String id, String name, int trophies, int highestTrophies, int coins) {}

    public record AuditDTO(long id, String createdAt, String adminName, String action, String playerId, String playerName,
                           String oldValue, String newValue, String reason) {
        static AuditDTO of(AdminAuditEntry a) {
            return new AuditDTO(a.getId(), a.getCreatedAt().toString(), a.getAdminName(), a.getAction(), a.getPlayerId(),
                    a.getPlayerName(), a.getOldValue(), a.getNewValue(), a.getReason());
        }
    }

    @Inject
    EntityManager em;

    @Inject
    AdminAudit audit;

    @POST
    @Path("/corrections/{id}")
    @Transactional
    public AdjustResult adjust(@PathParam("id") String id, AdjustRequest req) {
        if (req == null || req.reason() == null || req.reason().trim().length() < 3) {
            throw new WebApplicationException("Bitte einen Grund angeben (mindestens 3 Zeichen)", 400);
        }
        if (req.trophies() == null && req.coins() == null) {
            throw new WebApplicationException("Nichts zu ändern", 400);
        }
        for (Integer v : new Integer[]{req.trophies(), req.coins()}) {
            if (v != null && (v < 0 || v > MAX_VALUE)) {
                throw new WebApplicationException("Werte zwischen 0 und " + MAX_VALUE, 400);
            }
        }
        Player p = em.find(Player.class, id, LockModeType.PESSIMISTIC_WRITE);
        if (p == null) throw new WebApplicationException("Spieler nicht gefunden", 404);
        String reason = req.reason().trim();

        if (req.trophies() != null && req.trophies() != p.getTrophies()) {
            int old = p.getTrophies();
            p.setTrophies(req.trophies());
            audit.log("TROPHIES", p.getId(), p.getName(), old, req.trophies(), reason);
        }
        if (Boolean.TRUE.equals(req.resetRecord()) && p.getHighestTrophies() != p.getTrophies()) {
            int old = p.getHighestTrophies();
            p.setHighestTrophies(p.getTrophies());
            audit.log("RECORD", p.getId(), p.getName(), old, p.getTrophies(), reason);
        }
        if (req.coins() != null && req.coins() != p.getPoints()) {
            int old = p.getPoints();
            p.setPoints(req.coins());
            audit.log("COINS", p.getId(), p.getName(), old, req.coins(), reason);
        }
        return new AdjustResult(p.getId(), p.getName(), p.getTrophies(), p.getHighestTrophies(), p.getPoints());
    }

    /** Protokoll, neueste zuerst; mit playerId nur Einträge zu diesem Spieler. */
    @GET
    @Path("/audit")
    public List<AuditDTO> audit(@QueryParam("playerId") String playerId, @QueryParam("limit") @DefaultValue("100") int limit) {
        return audit.recent(playerId == null || playerId.isBlank() ? null : playerId, limit).stream().map(AuditDTO::of).toList();
    }
}
