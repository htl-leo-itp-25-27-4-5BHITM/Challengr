package control;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

/** Feste Check-in-Punkte. Einmal am Tag einchecken gibt Punkte, der Erste des Tages bekommt einen Bonus. */
public final class HotspotCatalog {

    public record Hotspot(String id, String name, double latitude, double longitude, double radiusMeters) {}

    public static final List<Hotspot> ALL = List.of(
            new Hotspot("htl-leonding", "HTL Leonding", 48.26832, 14.25138, 60)
    );

    /** Punkte für den täglichen Check-in. */
    public static final int DAILY_POINTS = 10;
    /** Zusätzlich für den ersten Check-in des Tages an diesem Hotspot. */
    public static final int FIRST_OF_DAY_BONUS = 15;

    /** "Heute" zählt nach österreichischer Zeit, nicht nach Server-Zeitzone. */
    public static final ZoneId ZONE = ZoneId.of("Europe/Vienna");

    private HotspotCatalog() {}

    public static Optional<Hotspot> find(String id) {
        return ALL.stream().filter(h -> h.id().equals(id)).findFirst();
    }

    public static LocalDate today() {
        return LocalDate.now(ZONE);
    }

    /** Entfernung in Metern (Haversine). */
    public static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
        final int r = 6371000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
