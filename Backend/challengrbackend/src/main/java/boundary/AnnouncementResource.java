package boundary;

import control.AdminAudit;
import entity.Announcement;
import io.quarkus.security.Authenticated;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.time.Instant;
import java.util.List;

/** Ankündigungen: die App holt die aktuelle, das Dashboard legt sie an und beendet sie. */
@Path("/api/announcement")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class AnnouncementResource {

    public record AnnouncementDTO(long id, String text, String startsAt, String endsAt, boolean active, boolean showing,
                                  String createdAt, String createdBy) {
        static AnnouncementDTO of(Announcement a) {
            return new AnnouncementDTO(a.getId(), a.getText(), a.getStartsAt() == null ? null : a.getStartsAt().toString(),
                    a.getEndsAt() == null ? null : a.getEndsAt().toString(), a.isActive(), a.isShowing(Instant.now()),
                    a.getCreatedAt().toString(), a.getCreatedBy());
        }
    }

    public record AnnouncementInput(String text, String startsAt, String endsAt) {}

    @Inject
    EntityManager em;

    @Inject
    AdminAudit audit;

    /** Für die App: die neueste Ankündigung, die gerade gilt – sonst 204. */
    @GET
    @Authenticated
    @Transactional
    public Response current() {
        Instant now = Instant.now();
        return em.createQuery("SELECT a FROM Announcement a WHERE a.active = true ORDER BY a.createdAt DESC", Announcement.class)
                .setMaxResults(20).getResultStream().filter(a -> a.isShowing(now)).findFirst()
                .map(a -> Response.ok(AnnouncementDTO.of(a)).build())
                .orElseGet(() -> Response.noContent().build());
    }

}
