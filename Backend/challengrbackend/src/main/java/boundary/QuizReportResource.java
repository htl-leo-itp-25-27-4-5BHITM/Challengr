package boundary;

import entity.Challenges;
import entity.QuizReport;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import security.CurrentPlayer;

/** „Frage melden“ aus der Quiz-Show – landet im Dashboard unter Quiz. */
@Path("/api/quiz/questions")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
@Authenticated
public class QuizReportResource {

    public record ReportRequest(String reason, String comment) {}

    @Inject
    EntityManager em;

    @Inject
    CurrentPlayer me;

    @POST
    @Path("/{id}/report")
    @Transactional
    public Response report(@PathParam("id") long id, ReportRequest req) {
        Challenges c = em.find(Challenges.class, id);
        if (c == null || c.getCorrectIndex() == null) throw new WebApplicationException("Frage nicht gefunden", 404);
        QuizReport.Reason reason;
        try {
            reason = QuizReport.Reason.valueOf(req == null || req.reason() == null ? "SONSTIGES" : req.reason());
        } catch (IllegalArgumentException e) {
            throw new WebApplicationException("Unbekannter Grund", 400);
        }
        String comment = req == null || req.comment() == null ? null : req.comment().trim();
        if (comment != null && comment.length() > 300) comment = comment.substring(0, 300);
        // pro Spieler und Frage nur eine offene Meldung (kein Spam)
        long open = em.createQuery("""
                        SELECT COUNT(r) FROM QuizReport r WHERE r.challengeId = :c AND r.playerId = :p AND r.status = :s
                        """, Long.class)
                .setParameter("c", id).setParameter("p", me.id()).setParameter("s", QuizReport.Status.OPEN).getSingleResult();
        if (open == 0) em.persist(new QuizReport(id, me.id(), reason, comment == null || comment.isEmpty() ? null : comment));
        return Response.noContent().build();
    }
}
