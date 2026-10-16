package boundary;

import control.AdminStatsService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;

/** Analysen fürs Admin-Dashboard (echte Spieldaten). Nur für Admins. */
@Path("/api/admin/stats")
@Produces(MediaType.APPLICATION_JSON)
@RolesAllowed("admin")
public class AdminStatsResource {

    @Inject
    AdminStatsService service;

    /** @param days Zeitraum für Verläufe und Verteilungen (7–90 Tage) */
    @GET
    public AdminStatsService.Stats stats(@QueryParam("days") @DefaultValue("30") int days) {
        return service.stats(Math.max(7, Math.min(90, days)));
    }
}
