package control;

import entity.Player;

import java.time.Duration;
import java.time.Instant;

/**
 * A5: Standorte anderer Spieler schützen (viele Nutzer sind minderjährig).
 * - "nearby" nur um die eigene, serverseitig gespeicherte Position, Radius hart begrenzt
 * - nur kürzlich aktive und nicht unsichtbare Spieler
 * - fremde Koordinaten nur gerundet (Raster ca. 50 m)
 */
public final class LocationPrivacy {

    /** Größter erlaubter Umkreis für "nearby" (größere Anfragen werden abgeschnitten). */
    public static final double MAX_NEARBY_RADIUS_METERS = 300;
    /** Wer länger nicht aktiv war, gilt als offline. */
    public static final Duration ACTIVE_WINDOW = Duration.ofMinutes(5);
    /** Raster für fremde Koordinaten: 0.0005° ≈ 55 m (Breite) bzw. ≈ 37 m (Länge in Österreich). */
    public static final double GRID_DEGREES = 0.0005;

    private LocationPrivacy() {}

    public static double clampRadius(double requested) {
        if (Double.isNaN(requested) || requested <= 0) return MAX_NEARBY_RADIUS_METERS;
        return Math.min(requested, MAX_NEARBY_RADIUS_METERS);
    }

    /** Auf das Raster runden – fremde Spieler sieht man nie metergenau. */
    public static double coarse(double degrees) {
        return Math.round(degrees / GRID_DEGREES) * GRID_DEGREES;
    }

    public static boolean hasPosition(Player p) {
        return p.getLatitude() != 0 && p.getLongitude() != 0;
    }

    public static boolean isActive(Player p, Instant now) {
        return p.getLastSeenAt() != null && p.getLastSeenAt().isAfter(now.minus(ACTIVE_WINDOW));
    }

    /** Darf {@code other} anderen Spielern auf der Karte angezeigt werden? */
    public static boolean visibleToOthers(Player other, Instant now) {
        return other != null && !other.isInvisible() && hasPosition(other) && isActive(other, now)
                && (other.getBanUntil() == null || !other.getBanUntil().isAfter(now));
    }

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
