package boundary;

import entity.Player;
import entity.PlayerReport;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.time.Instant;
import java.util.List;

/** B2: Meldungen im Dashboard – Sperren läuft über das bestehende Ban-System. */
@Path("/api/admin/reports")
@Produces(MediaType.APPLICATION_JSON)
@RolesAllowed("admin")
public class AdminReportResource {

    public record ReportDTO(Long id, String reporterId, String reporterName, String reportedId, String reportedName,
                            String reason, String comment, String status, Instant createdAt, Instant reportedBanUntil) {}

    @Inject
    EntityManager em;

    @GET
    public List<ReportDTO> list(@QueryParam("status") @DefaultValue("OPEN") String status) {
        var query = "ALL".equalsIgnoreCase(status)
                ? em.createQuery("SELECT r FROM PlayerReport r ORDER BY r.createdAt DESC", PlayerReport.class)
                : em.createQuery("SELECT r FROM PlayerReport r WHERE r.status = :s ORDER BY r.createdAt DESC", PlayerReport.class)
                    .setParameter("s", PlayerReport.Status.valueOf(status.toUpperCase()));
        return query.setMaxResults(500).getResultList().stream().map(this::toDTO).toList();
    }

    @POST
    @Path("/{id}/resolve")
    @Transactional
    public ReportDTO resolve(@PathParam("id") Long id) {
        PlayerReport r = em.find(PlayerReport.class, id);
        if (r == null) throw new NotFoundException();
        r.setStatus(PlayerReport.Status.RESOLVED);
        return toDTO(r);
    }

    private ReportDTO toDTO(PlayerReport r) {
        Player reporter = em.find(Player.class, r.getReporterId());
        Player reported = em.find(Player.class, r.getReportedId());
        return new ReportDTO(r.getId(), r.getReporterId(), reporter == null ? null : reporter.getName(),
                r.getReportedId(), reported == null ? null : reported.getName(), r.getReason().name(), r.getComment(),
                r.getStatus().name(), r.getCreatedAt(), reported == null ? null : reported.getBanUntil());
    }
}
