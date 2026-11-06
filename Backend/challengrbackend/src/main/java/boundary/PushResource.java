package boundary;

import control.PushTokenRepository;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import security.CurrentPlayer;

/** Gerät für Push-Benachrichtigungen an- und abmelden. */
@Path("/api/push")
@Authenticated
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class PushResource {

    /** token = APNs-Gerätetoken (hex), topic = Bundle-ID, sandbox = Entwickler-Build */
    public record DeviceDTO(String token, String topic, boolean sandbox) {}

    @Inject
    CurrentPlayer me;

    @Inject
    PushTokenRepository tokens;

    @POST
    @Path("/token")
    public void register(DeviceDTO dto) {
        if (dto == null || dto.token() == null || !dto.token().matches("[0-9a-fA-F]{32,200}")) {
            throw new WebApplicationException("Ungültiges Token", 400);
        }
        if (dto.topic() == null || !dto.topic().matches("[A-Za-z0-9.\\-]{3,100}")) {
            throw new WebApplicationException("Ungültige App", 400);
        }
        tokens.register(me.id(), dto.token().toLowerCase(), dto.topic(), dto.sandbox());
    }

    @DELETE
    @Path("/token/{token}")
    public void unregister(@PathParam("token") String token) {
        tokens.remove(me.id(), token.toLowerCase());
    }
}
