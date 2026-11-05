package boundary;

import control.AdminAudit;
import control.HotspotCatalog;
import control.LocationPrivacy;
import entity.CustomSpot;
import entity.Landmark;
import entity.LandmarkHidden;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;

/** Check-in-Orte im Dashboard: OpenStreetMap-Orte ausblenden, eigene Orte, beliebteste Orte, Heatmap. */
@Path("/api/admin/spots")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("admin")
public class AdminSpotResource {

    /** Heatmap: Raster ~250 m, Zellen mit weniger Spielern werden nicht gezeigt (niemand einzeln erkennbar). */
    static final double CELL_DEG = 0.0025;
    static final int MIN_PLAYERS_PER_CELL = 3;

    public record LandmarkDTO(String id, String name, String category, double latitude, double longitude,
                              boolean hidden, long checkins30d) {}

    public record HideInput(String reason) {}

    public record SpotInput(String name, Double latitude, Double longitude, Double radiusMeters, Integer points, Integer bonus) {}

    public record SpotDTO(String id, String name, double latitude, double longitude, double radiusMeters, int points,
                          int bonus, boolean active, long checkins30d) {}

    public record PopularDTO(String id, String name, String kind, Double latitude, Double longitude, long checkins, long players) {}

    public record HeatCell(double latitude, double longitude, long players) {}

    public record Heatmap(int days, int minPlayersPerCell, long playersWithPosition, List<HeatCell> cells, List<PopularDTO> spots) {}

    @Inject
    EntityManager em;

    @Inject
    AdminAudit audit;

    @GET
    @Path("/landmarks")
    @Transactional
    public List<LandmarkDTO> landmarks(@QueryParam("q") String query, @QueryParam("hidden") boolean onlyHidden) {
        Set<String> hidden = new HashSet<>(em.createQuery("SELECT h.id FROM LandmarkHidden h", String.class).getResultList());
        Map<String, Long> checkins = checkinCounts(30);
        String q = query == null ? "" : query.trim().toLowerCase();
        List<LandmarkDTO> out = new ArrayList<>(em.createQuery("SELECT l FROM Landmark l", Landmark.class).getResultStream()
                .filter(l -> q.isEmpty() || l.getName().toLowerCase().contains(q))
                .filter(l -> !onlyHidden || hidden.contains(l.getId()))
                .map(l -> new LandmarkDTO(l.getId(), l.getName(), l.getCategory(), l.getLatitude(), l.getLongitude(),
                        hidden.contains(l.getId()), checkins.getOrDefault(l.getId(), 0L)))
                .sorted(Comparator.comparingLong(LandmarkDTO::checkins30d).reversed().thenComparing(LandmarkDTO::name))
                .limit(200).toList());
        // ausgeblendete, deren Kachel inzwischen ohne sie neu geladen wurde
        if (onlyHidden || !q.isEmpty()) {
            Set<String> listed = new HashSet<>(out.stream().map(LandmarkDTO::id).toList());
            em.createQuery("SELECT h FROM LandmarkHidden h", LandmarkHidden.class).getResultStream()
                    .filter(h -> !listed.contains(h.getId()) && (q.isEmpty() || (h.getName() != null && h.getName().toLowerCase().contains(q))))
                    .forEach(h -> out.add(new LandmarkDTO(h.getId(), h.getName(), null, 0, 0, true, 0)));
        }
        return out;
    }

    @POST
    @Path("/landmarks/{id}/hide")
    @Transactional
    public void hide(@PathParam("id") String id, HideInput in) {
        if (em.find(LandmarkHidden.class, id) != null) return;
        Landmark l = em.find(Landmark.class, id);
        if (l == null) throw new WebApplicationException("Ort nicht gefunden", 404);
        String reason = in == null || in.reason() == null ? null : in.reason().trim();
        em.persist(new LandmarkHidden(id, l.getName(), reason));
        audit.log("SPOT_HIDE", null, null, null, l.getName(), reason == null || reason.isEmpty() ? "Ort ausgeblendet" : reason);
    }

    @DELETE
    @Path("/landmarks/{id}/hide")
    @Transactional
    public void unhide(@PathParam("id") String id) {
        LandmarkHidden h = em.find(LandmarkHidden.class, id);
        if (h == null) return;
        em.remove(h);
        audit.log("SPOT_SHOW", null, null, null, h.getName(), "Ort wieder eingeblendet");
    }

    @GET
    @Path("/custom")
    @Transactional
    public List<SpotDTO> custom() {
        Map<String, Long> checkins = checkinCounts(30);
        return em.createQuery("SELECT c FROM CustomSpot c ORDER BY c.createdAt DESC", CustomSpot.class).getResultStream()
                .map(c -> toDTO(c, checkins.getOrDefault(c.getId(), 0L))).toList();
    }

    @POST
    @Path("/custom")
    @Transactional
    public SpotDTO create(SpotInput in) {
        CustomSpot c = new CustomSpot();
        c.setId("custom-" + Long.toString(System.currentTimeMillis(), 36));
        apply(c, in);
        em.persist(c);
        audit.log("SPOT_NEW", null, null, null, c.getName() + " (" + c.getLatitude() + ", " + c.getLongitude() + ")", "Eigener Ort");
        return toDTO(c, 0);
    }

    @PUT
    @Path("/custom/{id}")
    @Transactional
    public SpotDTO update(@PathParam("id") String id, SpotInput in) {
        CustomSpot c = em.find(CustomSpot.class, id);
        if (c == null) throw new WebApplicationException("Ort nicht gefunden", 404);
        String before = c.getName();
        apply(c, in);
        c.setActive(true);
        audit.log("SPOT_EDIT", null, null, before, c.getName(), "Eigener Ort geändert");
        return toDTO(c, checkinCounts(30).getOrDefault(id, 0L));
    }

    /** Deaktivieren statt löschen – alte Check-ins verweisen noch darauf. */
    @DELETE
    @Path("/custom/{id}")
    @Transactional
    public void deactivate(@PathParam("id") String id) {
        CustomSpot c = em.find(CustomSpot.class, id);
        if (c == null) throw new WebApplicationException("Ort nicht gefunden", 404);
        c.setActive(false);
        audit.log("SPOT_OFF", null, null, null, c.getName(), "Eigener Ort deaktiviert");
    }

    @GET
    @Path("/popular")
    @Transactional
    public List<PopularDTO> popular(@QueryParam("days") @DefaultValue("30") int days) {
        int d = Math.max(1, Math.min(days, 365));
        List<Object[]> rows = em.createQuery("""
                        SELECT c.hotspotId, COUNT(c), COUNT(DISTINCT c.playerId) FROM HotspotCheckin c
                        WHERE c.day >= :from GROUP BY c.hotspotId ORDER BY COUNT(c) DESC
                        """, Object[].class)
                .setParameter("from", LocalDate.now(HotspotCatalog.ZONE).minusDays(d - 1L)).setMaxResults(30).getResultList();
        return rows.stream().map(r -> describe((String) r[0], (Long) r[1], (Long) r[2])).toList();
    }

    /** Wo gespielt wird: Spieler-Positionen der letzten Tage in groben Zellen, nur Zellen mit ≥ 3 Spielern, keine Namen. */
    @GET
    @Path("/heatmap")
    @Transactional
    public Heatmap heatmap(@QueryParam("days") @DefaultValue("14") int days) {
        int d = Math.max(1, Math.min(days, 90));
        Instant since = Instant.now().minus(d, ChronoUnit.DAYS);
        List<entity.Player> players = em.createQuery("SELECT p FROM Player p WHERE p.lastSeenAt >= :s", entity.Player.class)
                .setParameter("s", since).getResultList().stream().filter(LocationPrivacy::hasPosition).toList();
        Map<String, long[]> cells = new HashMap<>();
        for (entity.Player p : players) {
            long a = Math.round(p.getLatitude() / CELL_DEG), b = Math.round(p.getLongitude() / CELL_DEG);
            cells.computeIfAbsent(a + ":" + b, k -> new long[]{a, b, 0})[2]++;
        }
        List<HeatCell> visible = cells.values().stream().filter(c -> c[2] >= MIN_PLAYERS_PER_CELL)
                .map(c -> new HeatCell(c[0] * CELL_DEG, c[1] * CELL_DEG, c[2]))
                .sorted(Comparator.comparingLong(HeatCell::players).reversed()).toList();
        return new Heatmap(d, MIN_PLAYERS_PER_CELL, players.size(), visible, popular(30));
    }

    // ---------------------------------------------------------

    private Map<String, Long> checkinCounts(int days) {
        Map<String, Long> m = new HashMap<>();
        em.createQuery("SELECT c.hotspotId, COUNT(c) FROM HotspotCheckin c WHERE c.day >= :from GROUP BY c.hotspotId", Object[].class)
                .setParameter("from", LocalDate.now(HotspotCatalog.ZONE).minusDays(days - 1L))
                .getResultStream().forEach(r -> m.put((String) r[0], (Long) r[1]));
        return m;
    }

    private PopularDTO describe(String id, long checkins, long players) {
        var school = HotspotCatalog.find(id);
        if (school.isPresent()) {
            return new PopularDTO(id, school.get().name(), "Schule", school.get().latitude(), school.get().longitude(), checkins, players);
        }
        CustomSpot c = em.find(CustomSpot.class, id);
        if (c != null) return new PopularDTO(id, c.getName(), "Eigener Ort", c.getLatitude(), c.getLongitude(), checkins, players);
        Landmark l = em.find(Landmark.class, id);
        if (l != null) return new PopularDTO(id, l.getName(), "OpenStreetMap", l.getLatitude(), l.getLongitude(), checkins, players);
        LandmarkHidden h = em.find(LandmarkHidden.class, id);
        return new PopularDTO(id, h != null ? h.getName() + " (ausgeblendet)" : id, "?", null, null, checkins, players);
    }

    private static void apply(CustomSpot c, SpotInput in) {
        if (in == null || in.name() == null || in.name().trim().length() < 3 || in.name().trim().length() > 80) {
            throw new WebApplicationException("Name: 3–80 Zeichen", 400);
        }
        if (in.latitude() == null || in.longitude() == null || Math.abs(in.latitude()) > 90 || Math.abs(in.longitude()) > 180) {
            throw new WebApplicationException("Ungültige Koordinaten", 400);
        }
        double radius = in.radiusMeters() == null ? 60 : in.radiusMeters();
        if (radius < 20 || radius > 300) throw new WebApplicationException("Radius 20–300 m", 400);
        int points = in.points() == null ? HotspotCatalog.DAILY_POINTS : in.points();
        int bonus = in.bonus() == null ? HotspotCatalog.FIRST_OF_DAY_BONUS : in.bonus();
        if (points < 0 || points > 100 || bonus < 0 || bonus > 100) throw new WebApplicationException("Coins 0–100", 400);
        c.setName(in.name().trim());
        c.setLatitude(in.latitude());
        c.setLongitude(in.longitude());
        c.setRadiusMeters(radius);
        c.setPoints(points);
        c.setBonus(bonus);
    }

    private static SpotDTO toDTO(CustomSpot c, long checkins) {
        return new SpotDTO(c.getId(), c.getName(), c.getLatitude(), c.getLongitude(), c.getRadiusMeters(), c.getPoints(),
                c.getBonus(), c.isActive(), checkins);
    }
}
