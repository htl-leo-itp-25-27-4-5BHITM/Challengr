package boundary;

import control.BlockRepository;
import control.PlayerRepository;
import entity.Player;
import entity.PlayerReport;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import security.CurrentPlayer;

import java.util.List;

/**
 * B2 (Apple-Regel 1.2): andere Spieler melden und blockieren.
 * Blockieren wirkt in beide Richtungen: Karte, Herausfordern, Freundschaft und Emotes.
 */
@Path("/api/safety")
@Produces(MediaType.APPLICATION_JSON)
@Authenticated
public class SafetyResource {

    public record BlockedPlayerDTO(String id, String name) {}

    public record ReportRequest(String reason, String comment) {}

    @Inject
    CurrentPlayer me;

    @Inject
    BlockRepository blocks;

    @Inject
    PlayerRepository players;

    @Inject
    EntityManager em;

    @POST
    @Path("/blocks/{playerId}")
    public Response block(@PathParam("playerId") String playerId) {
        String self = me.id();
        if (self.equals(playerId)) throw new WebApplicationException("Du kannst dich nicht selbst blockieren", 400);
        if (players.findById(playerId) == null) throw new NotFoundException("Spieler nicht gefunden");
        blocks.block(self, playerId);
        GameSocket.emitFriendRemoved(self, playerId);
        return Response.noContent().build();
    }

    @DELETE
    @Path("/blocks/{playerId}")
    public Response unblock(@PathParam("playerId") String playerId) {
        blocks.unblock(me.id(), playerId);
        return Response.noContent().build();
    }

    @GET
    @Path("/blocks")
    public List<BlockedPlayerDTO> blocked() {
        return blocks.blockedBy(me.id()).stream()
                .map(id -> {
                    Player p = players.findById(id);
                    return new BlockedPlayerDTO(id, p == null ? "Gelöschter Spieler" : p.getName());
                })
                .toList();
    }

    @POST
    @Path("/reports/{playerId}")
    @Consumes(MediaType.APPLICATION_JSON)
    @Transactional
    public Response report(@PathParam("playerId") String playerId, ReportRequest body) {
        String self = me.id();
        if (self.equals(playerId)) throw new WebApplicationException("Du kannst dich nicht selbst melden", 400);
        if (players.findById(playerId) == null) throw new NotFoundException("Spieler nicht gefunden");
        PlayerReport.Reason reason;
        try {
            reason = PlayerReport.Reason.valueOf(body == null || body.reason() == null ? "SONSTIGES" : body.reason());
        } catch (IllegalArgumentException e) {
            throw new WebApplicationException("Unbekannter Grund", 400);
        }
        // Gegen Spam: höchstens eine offene Meldung pro Paar
        long open = em.createQuery("""
                        SELECT COUNT(r) FROM PlayerReport r
                        WHERE r.reporterId = :a AND r.reportedId = :b AND r.status = :open
                        """, Long.class)
                .setParameter("a", self).setParameter("b", playerId)
                .setParameter("open", PlayerReport.Status.OPEN).getSingleResult();
        if (open == 0) {
            PlayerReport r = new PlayerReport();
            r.setReporterId(self);
            r.setReportedId(playerId);
            r.setReason(reason);
            String comment = body == null || body.comment() == null ? null : body.comment().trim();
            r.setComment(comment == null || comment.isEmpty() ? null : comment.substring(0, Math.min(500, comment.length())));
            em.persist(r);
        }
        return Response.noContent().build();
    }
}
