package boundary;

import control.AppStoreConnectClient;
import control.TestFlightFeedbackService;
import io.quarkus.security.identity.SecurityIdentity;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.util.Map;

/** TestFlight-Feedback im Dashboard: ansehen und abhaken. Nur für Admins. */
@Path("/api/admin/feedback")
@Produces(MediaType.APPLICATION_JSON)
@RolesAllowed("admin")
public class AdminFeedbackResource {

    /** IDs von Apple: Buchstaben, Ziffern, Bindestriche – alles andere wird abgelehnt (kein Pfad-Trick zu Apple). */
    private static final String ID = "[A-Za-z0-9_-]{1,64}";

    public record DoneRequest(boolean done) {}

    @Inject
    TestFlightFeedbackService service;

    @Inject
    SecurityIdentity identity;

    @GET
    public TestFlightFeedbackService.Feed list(@QueryParam("refresh") @DefaultValue("false") boolean refresh) {
        return service.feed(refresh);
    }

    @PUT
    @Path("/{id}/done")
    @Consumes(MediaType.APPLICATION_JSON)
    public Map<String, Object> done(@PathParam("id") String id, DoneRequest body) {
        if (!id.matches(ID)) throw new BadRequestException("Ungültige ID");
        boolean done = body != null && body.done();
        service.setDone(id, done, identity.getPrincipal().getName());
        return Map.of("id", id, "done", done);
    }

    /** ZIP mit feedback.md, Screenshots und Absturzberichten. */
    @GET
    @Path("/export")
    @Produces("application/zip")
    public jakarta.ws.rs.core.Response export(@QueryParam("filter") @DefaultValue("open") String filter) {
        if (!java.util.List.of("open", "done", "all").contains(filter)) throw new BadRequestException("Ungültiger Filter");
        if (!service.isConfigured()) throw new WebApplicationException("App Store Connect ist nicht eingerichtet", 503);
        String file = "challengr-feedback-" + java.time.LocalDate.now(java.time.ZoneId.of("Europe/Vienna")) + ".zip";
        return jakarta.ws.rs.core.Response.ok(service.exportZip(filter))
                .header("Content-Disposition", "attachment; filename=\"" + file + "\"")
                .build();
    }

    @GET
    @Path("/{id}/crash-log")
    public Map<String, String> crashLog(@PathParam("id") String id) {
        if (!id.matches(ID)) throw new BadRequestException("Ungültige ID");
        if (!service.isConfigured()) throw new WebApplicationException("App Store Connect ist nicht eingerichtet", 503);
        try {
            return Map.of("text", service.crashLog(id));
        } catch (AppStoreConnectClient.AscException e) {
            throw new WebApplicationException(e.getMessage(), e.status == 404 ? 404 : 502);
        }
    }
}
