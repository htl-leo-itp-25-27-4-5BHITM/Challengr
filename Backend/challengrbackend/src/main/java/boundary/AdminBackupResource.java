package boundary;

import control.AdminAudit;
import control.BackupService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.io.IOException;
import java.util.List;
import java.util.Map;

/** Datenbank-Sicherungen im Dashboard: Liste, „Backup jetzt“, herunterladen. */
@Path("/api/admin/backups")
@Produces(MediaType.APPLICATION_JSON)
@RolesAllowed("admin")
public class AdminBackupResource {

    @Inject
    BackupService backups;

    @Inject
    AdminAudit audit;

    public record BackupOverview(boolean available, String lastSuccess, String lastError, List<BackupService.BackupFile> files) {}

    @GET
    public BackupOverview list() throws IOException {
        return new BackupOverview(backups.available(),
                backups.lastSuccess() == null ? null : backups.lastSuccess().toString(), backups.lastError(), backups.list());
    }

    @POST
    @Transactional
    public Response create() {
        try {
            BackupService.BackupFile file = backups.create(false);
            audit.log("BACKUP", null, null, null, file.name(), "Backup im Dashboard erstellt");
            return Response.ok(file).build();
        } catch (IllegalStateException e) {
            return Response.status(409).entity(Map.of("message", e.getMessage())).build();
        } catch (IOException e) {
            return Response.status(503).entity(Map.of("message", e.getMessage())).build();
        }
    }

    @GET
    @Path("/{name}")
    @Produces("application/gzip")
    public Response download(@PathParam("name") String name) {
        return backups.file(name)
                .map(f -> Response.ok(f.toFile()).header("Content-Disposition", "attachment; filename=\"" + name + "\"").build())
                .orElseGet(() -> Response.status(404).build());
    }
}
