package boundary;

import control.PlayerRepository;
import control.RiftBossService;
import entity.Player;
import io.quarkus.security.Authenticated;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import security.CurrentPlayer;

import java.util.List;
import java.util.Map;

/** Riss-Wächter: wer ist in der Nähe (nach der Server-Position des Spielers) und wie viele Riss-Splitter hat man. */
@Path("/api/bosses")
@Produces(MediaType.APPLICATION_JSON)
@Authenticated
public class BossResource {

    /** So weit sieht man einen Riss auf der Karte */
    static final double VISIBLE_RADIUS_M = 3000;

    public record Nearby(List<RiftBossService.View> bosses, int shards) {}

    @Inject
    RiftBossService bosses;

    @Inject
    PlayerRepository players;

    @Inject
    CurrentPlayer current;

    @GET
    @Path("/nearby")
    @Transactional
    public Nearby nearby() {
        Player me = players.findById(current.id());
        if (me == null) return new Nearby(List.of(), 0);
        return new Nearby(bosses.near(me.getLatitude(), me.getLongitude(), VISIBLE_RADIUS_M), me.getRiftShards());
    }

    /** Dashboard/Test: einen Riss an einem öffentlichen Ort öffnen. Body: {"place": "...", "latitude": .., "longitude": ..} */
    @POST
    @Path("/spawn")
    @RolesAllowed("admin")
    @Consumes(MediaType.APPLICATION_JSON)
    public RiftBossService.View spawn(Map<String, Object> body) {
        String place = String.valueOf(body.getOrDefault("place", "Riss"));
        double lat = ((Number) body.get("latitude")).doubleValue();
        double lon = ((Number) body.get("longitude")).doubleValue();
        var b = bosses.spawn(place, lat, lon);
        return bosses.near(lat, lon, 1).stream().filter(v -> v.id() == b.id).findFirst().orElseThrow();
    }
}
