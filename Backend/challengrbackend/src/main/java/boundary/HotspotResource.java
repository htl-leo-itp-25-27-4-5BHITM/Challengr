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

/** Hotspots: fixe Check-in-Punkte (z.B. die Schule) und Orte aus OpenStreetMap, jeweils mit täglichem Bonus. */
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

    /** kind: "school" (feste Hotspots) oder "landmark" (aus OpenStreetMap); category nur bei landmark */
    public record HotspotDTO(String id, String name, double latitude, double longitude, double radiusMeters,
                             int points, int firstOfDayBonus, boolean checkedInToday, long checkinsToday,
                             String kind, String category) {}

    public record CheckinRequest(String playerId, Double latitude, Double longitude) {}

    public record CheckinResultDTO(String hotspotId, int points, boolean firstOfDay, int totalPoints) {}

    /** Ein Check-in-Punkt, egal woher (fest oder OpenStreetMap). */
    private record Spot(String id, String name, double latitude, double longitude, double radiusMeters,
                        int points, int bonus, String kind, String category) {
        static Spot of(HotspotCatalog.Hotspot h) {
            return new Spot(h.id(), h.name(), h.latitude(), h.longitude(), h.radiusMeters(),
                    HotspotCatalog.DAILY_POINTS, HotspotCatalog.FIRST_OF_DAY_BONUS, "school", null);
        }

        static Spot of(entity.Landmark l) {
            return new Spot(l.getId(), l.getName(), l.getLatitude(), l.getLongitude(), l.getRadiusMeters(),
                    HotspotCatalog.LANDMARK_POINTS, HotspotCatalog.LANDMARK_FIRST_OF_DAY_BONUS, "landmark", l.getCategory());
        }

        static Spot of(entity.CustomSpot c) {
            return new Spot(c.getId(), c.getName(), c.getLatitude(), c.getLongitude(), c.getRadiusMeters(),
                    c.getPoints(), c.getBonus(), "custom", null);
        }

        boolean isLandmark() { return "landmark".equals(kind); }
    }

    @Inject
    control.LandmarkService landmarks;

    @Inject
    jakarta.persistence.EntityManager em;

    @GET
    @Transactional
    public List<HotspotDTO> list(@QueryParam("playerId") String requested) {
        // Eingecheckt-Status nur für das eigene Konto; Orte um die beim Server gespeicherte Position (nicht frei wählbar)
        String playerId = me.id();
        LocalDate today = HotspotCatalog.today();
        java.util.List<Spot> spots = new java.util.ArrayList<>(HotspotCatalog.ALL.stream().map(Spot::of).toList());
        // eigene Orte aus dem Dashboard: für alle sichtbar wie die Schule
        em.createQuery("SELECT c FROM CustomSpot c WHERE c.active = true", entity.CustomSpot.class)
                .getResultStream().forEach(c -> spots.add(Spot.of(c)));
        Player player = playerId == null ? null : playerRepository.findById(playerId);
        if (player != null && control.LocationPrivacy.hasPosition(player)) {
            landmarks.near(player.getLatitude(), player.getLongitude()).forEach(l -> spots.add(Spot.of(l)));
        }
        return spots.stream()
                .map(h -> new HotspotDTO(h.id(), h.name(), h.latitude(), h.longitude(), h.radiusMeters(), h.points(), h.bonus(),
                        playerId != null && hotspotRepository.hasCheckedIn(playerId, h.id(), today),
                        hotspotRepository.countOnDay(h.id(), today), h.kind(), h.category()))
                .toList();
    }

    /** Einchecken: nur im Radius und nur einmal pro Tag. */
    @POST
    @Path("/{id}/checkin")
    @Transactional
    public synchronized CheckinResultDTO checkin(@PathParam("id") String hotspotId, CheckinRequest req) {
        Spot hotspot = HotspotCatalog.find(hotspotId).map(Spot::of)
                .or(() -> landmarks.find(hotspotId).map(Spot::of))
                .or(() -> java.util.Optional.ofNullable(em.find(entity.CustomSpot.class, hotspotId))
                        .filter(entity.CustomSpot::isActive).map(Spot::of))
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

        if (hotspot.isLandmark() && hotspotRepository.countLandmarksOnDay(player.getId(), today) >= HotspotCatalog.LANDMARK_DAILY_LIMIT) {
            throw new WebApplicationException("Heute schon " + HotspotCatalog.LANDMARK_DAILY_LIMIT + " Orte besucht – morgen geht's weiter!", 429);
        }

        boolean first = hotspotRepository.countOnDay(hotspotId, today) == 0;
        int points = hotspot.points() + (first ? hotspot.bonus() : 0);

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
