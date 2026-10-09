package boundary;

import io.quarkus.security.Authenticated;
import security.CurrentPlayer;
import control.HotspotCatalog;
import control.HotspotRepository;
import control.PlayerRepository;
import entity.HotspotCheckin;
import entity.Player;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.time.LocalDate;
import java.util.List;

/** Hotspots: fixe Check-in-Punkte (z.B. die Schule) mit täglichem Bonus. */
@Path("/api/hotspots")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
@Authenticated
public class HotspotResource {

    @Inject
    CurrentPlayer me;

    @Inject
    HotspotRepository hotspotRepository;

    @Inject
    PlayerRepository playerRepository;

    public record HotspotDTO(String id, String name, double latitude, double longitude, double radiusMeters,
                             int points, int firstOfDayBonus, boolean checkedInToday, long checkinsToday) {}

    public record CheckinRequest(String playerId, Double latitude, Double longitude) {}

    public record CheckinResultDTO(String hotspotId, int points, boolean firstOfDay, int totalPoints) {}

    @GET
    public List<HotspotDTO> list(@QueryParam("playerId") String requested) {
        // Eingecheckt-Status nur für das eigene Konto
        String playerId = me.id();
        LocalDate today = HotspotCatalog.today();
        return HotspotCatalog.ALL.stream()
                .map(h -> new HotspotDTO(h.id(), h.name(), h.latitude(), h.longitude(), h.radiusMeters(),
                        HotspotCatalog.DAILY_POINTS, HotspotCatalog.FIRST_OF_DAY_BONUS,
                        playerId != null && hotspotRepository.hasCheckedIn(playerId, h.id(), today),
                        hotspotRepository.countOnDay(h.id(), today)))
                .toList();
    }

    /** Einchecken: nur im Radius und nur einmal pro Tag. */
    @POST
    @Path("/{id}/checkin")
    @Transactional
    public synchronized CheckinResultDTO checkin(@PathParam("id") String hotspotId, CheckinRequest req) {
        var hotspot = HotspotCatalog.find(hotspotId)
                .orElseThrow(() -> new WebApplicationException("Unbekannter Hotspot", 404));
        if (req == null || req.playerId() == null || req.latitude() == null || req.longitude() == null) {
            throw new WebApplicationException("playerId, latitude und longitude fehlen", 400);
        }
        me.requireSelf(req.playerId());
        Player player = playerRepository.findById(req.playerId());
        if (player == null) {
            throw new WebApplicationException("Player not found", 404);
        }
        double distance = HotspotCatalog.distanceMeters(req.latitude(), req.longitude(), hotspot.latitude(), hotspot.longitude());
        if (distance > hotspot.radiusMeters()) {
            throw new WebApplicationException("Zu weit weg (" + Math.round(distance) + " m) – geh näher zu " + hotspot.name(), 403);
        }
        LocalDate today = HotspotCatalog.today();
        if (hotspotRepository.hasCheckedIn(player.getId(), hotspotId, today)) {
            throw new WebApplicationException("Heute schon eingecheckt – morgen wieder!", 409);
        }

        boolean first = hotspotRepository.countOnDay(hotspotId, today) == 0;
        int points = HotspotCatalog.DAILY_POINTS + (first ? HotspotCatalog.FIRST_OF_DAY_BONUS : 0);

        HotspotCheckin checkin = new HotspotCheckin();
        checkin.setPlayerId(player.getId());
        checkin.setHotspotId(hotspotId);
        checkin.setDay(today);
        checkin.setPoints(points);
        checkin.setFirstOfDay(first);
        hotspotRepository.persist(checkin);

        player.setPoints(player.getPoints() + points);
        return new CheckinResultDTO(hotspotId, points, first, player.getPoints());
    }
}
