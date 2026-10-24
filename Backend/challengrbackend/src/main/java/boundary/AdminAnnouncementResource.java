package boundary;

import control.AdminAudit;
import entity.Announcement;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.time.Instant;
import java.util.List;

import boundary.AnnouncementResource.AnnouncementDTO;
import boundary.AnnouncementResource.AnnouncementInput;

/** Ankündigungen im Dashboard anlegen und beenden. */
@Path("/api/admin/announcements")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("admin")
public class AdminAnnouncementResource {

    @Inject
    EntityManager em;

    @Inject
    AdminAudit audit;

    @GET
    @Transactional
    public List<AnnouncementDTO> list() {
        return em.createQuery("SELECT a FROM Announcement a ORDER BY a.createdAt DESC", Announcement.class)
                .setMaxResults(30).getResultStream().map(AnnouncementDTO::of).toList();
    }

    @POST
    @Transactional
    public AnnouncementDTO create(AnnouncementInput in) {
        String text = in == null || in.text() == null ? "" : in.text().trim();
        if (text.length() < 3 || text.length() > 200) throw new WebApplicationException("Text: 3–200 Zeichen", 400);
        Instant start, end;
        try {
            start = in.startsAt() == null || in.startsAt().isBlank() ? null : Instant.parse(in.startsAt());
            end = in.endsAt() == null || in.endsAt().isBlank() ? null : Instant.parse(in.endsAt());
        } catch (Exception e) {
            throw new WebApplicationException("Ungültiges Datum", 400);
        }
        if (start != null && end != null && !end.isAfter(start)) throw new WebApplicationException("Ende liegt vor dem Start", 400);
        // immer nur eine Ankündigung gleichzeitig
        em.createQuery("UPDATE Announcement a SET a.active = false WHERE a.active = true").executeUpdate();
        Announcement a = new Announcement();
        a.setText(text);
        a.setStartsAt(start);
        a.setEndsAt(end);
        a.setCreatedBy(audit.adminName());
        em.persist(a);
        audit.log("ANNOUNCE", null, null, null, text, "Ankündigung erstellt");
        return AnnouncementDTO.of(a);
    }

    @DELETE
    @Path("/{id}")
    @Transactional
    public void end(@PathParam("id") long id) {
        Announcement a = em.find(Announcement.class, id);
        if (a == null) throw new WebApplicationException("Nicht gefunden", 404);
        if (a.isActive()) {
            a.setActive(false);
            audit.log("ANNOUNCE_END", null, null, a.getText(), null, "Ankündigung beendet");
        }
    }
}
