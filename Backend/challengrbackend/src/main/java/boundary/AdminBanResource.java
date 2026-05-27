package boundary;

import control.BanService;
import entity.Player;
import jakarta.annotation.security.PermitAll;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;

@Path("/api/admin/players")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@PermitAll // TODO tighten to admin role once Dashboard sends Bearer tokens
public class AdminBanResource {

    @Inject
    BanService banService;

    public record BanRequest(long durationSeconds, String reason) {
    }

    private record BanResponse(String id, Instant banUntil, String banReason) {
    }

    @POST
    @Path("/{playerId}/ban")
    public Response ban(@PathParam("playerId") String playerId, BanRequest req) {
        if (req == null || req.durationSeconds <= 0) {
            return Response.status(400).entity(Map.of(
                    "error", "invalid_request",
                    "message", "durationSeconds must be > 0"
            )).build();
        }

        try {
            Player p = banService.banPlayer(playerId, Duration.ofSeconds(req.durationSeconds), req.reason);
            return Response.ok(new BanResponse(p.getId(), p.getBanUntil(), p.getBanReason())).build();
        } catch (IllegalArgumentException e) {
            return Response.status(404).entity(Map.of(
                    "error", "not_found",
                    "message", e.getMessage()
            )).build();
        } catch (Exception e) {
            return Response.status(500).entity(Map.of(
                    "error", "ban_failed",
                    "message", e.getMessage() == null ? e.getClass().getName() : e.getMessage()
            )).build();
        }
    }

    @POST
    @Path("/{playerId}/unban")
    public Response unban(@PathParam("playerId") String playerId) {
        try {
            Player p = banService.unbanPlayer(playerId);
            return Response.ok(new BanResponse(p.getId(), p.getBanUntil(), p.getBanReason())).build();
        } catch (IllegalArgumentException e) {
            return Response.status(404).entity(Map.of(
                    "error", "not_found",
                    "message", e.getMessage()
            )).build();
        } catch (Exception e) {
            return Response.status(500).entity(Map.of(
                    "error", "unban_failed",
                    "message", e.getMessage() == null ? e.getClass().getName() : e.getMessage()
            )).build();
        }
    }
}
