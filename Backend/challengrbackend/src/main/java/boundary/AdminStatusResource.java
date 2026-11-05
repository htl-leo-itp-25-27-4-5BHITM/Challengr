package boundary;

import control.SystemStatusService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/api/admin/status")
@Produces(MediaType.APPLICATION_JSON)
@RolesAllowed("admin")
public class AdminStatusResource {

    @Inject
    SystemStatusService status;

    @GET
    public SystemStatusService.Status get() {
        return status.status();
    }
}
