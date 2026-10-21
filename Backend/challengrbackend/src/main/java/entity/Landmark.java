package entity;

import jakarta.persistence.*;

import java.time.Instant;

/** Check-in-Punkt aus OpenStreetMap (Park, Museum, Brunnen …), zwischengespeichert pro Kachel. */
@Entity
@Table(name = "landmark", indexes = {@Index(columnList = "tile_key"), @Index(columnList = "latitude")})
public class Landmark {

    /** z. B. "osm-w-12345" (Typ + OSM-Id) – auch die Hotspot-Id in der App */
    @Id
    @Column(length = 40)
    private String id;

    @Column(nullable = false, length = 120)
    private String name;

    private double latitude;
    private double longitude;

    /** park, museum, fountain, library, square … (für das Symbol in der App) */
    @Column(length = 32)
    private String category;

    @Column(name = "radius_meters")
    private double radiusMeters;

    @Column(name = "tile_key", length = 24, nullable = false)
    private String tileKey;

    @Column(name = "fetched_at")
    private Instant fetchedAt = Instant.now();

    public Landmark() {}

    public Landmark(String id, String name, double latitude, double longitude, String category, double radiusMeters, String tileKey) {
        this.id = id;
        this.name = name;
        this.latitude = latitude;
        this.longitude = longitude;
        this.category = category;
        this.radiusMeters = radiusMeters;
        this.tileKey = tileKey;
    }

    public String getId() { return id; }
    public String getName() { return name; }
    public double getLatitude() { return latitude; }
    public double getLongitude() { return longitude; }
    public String getCategory() { return category; }
    public double getRadiusMeters() { return radiusMeters; }
    public String getTileKey() { return tileKey; }
}
