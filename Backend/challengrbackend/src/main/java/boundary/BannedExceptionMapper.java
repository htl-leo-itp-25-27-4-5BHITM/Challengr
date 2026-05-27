package boundary;

import control.BannedException;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;

import java.util.Map;

@Provider
public class BannedExceptionMapper implements ExceptionMapper<BannedException> {
    @Override
    public Response toResponse(BannedException ex) {
        return Response.status(Response.Status.FORBIDDEN)
                .type(MediaType.APPLICATION_JSON)
                .entity(Map.of(
                        "error", "banned",
                        "message", "Player is banned",
                        "banUntil", ex.getBanUntil(),
                        "banReason", ex.getBanReason()
                ))
                .build();
    }
}
