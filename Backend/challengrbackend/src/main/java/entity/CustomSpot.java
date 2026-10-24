package entity;

import jakarta.persistence.*;

import java.time.Instant;

/** Eigener Check-in-Punkt aus dem Dashboard (z. B. eine weitere Schule) – für alle sichtbar wie die HTL. */
@Entity
@Table(name = "custom_spot")
public class CustomSpot {

    @Id
    @Column(length = 40)
    private String id;

    @Column(nullable = false, length = 80)
    private String name;

    private double latitude;
    private double longitude;

    @Column(name = "radius_meters")
    private double radiusMeters;

    private int points;
    private int bonus;

    @Column(columnDefinition = "boolean default true not null")
    private boolean active = true;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public CustomSpot() {}

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public double getLatitude() { return latitude; }
    public void setLatitude(double latitude) { this.latitude = latitude; }
    public double getLongitude() { return longitude; }
    public void setLongitude(double longitude) { this.longitude = longitude; }
    public double getRadiusMeters() { return radiusMeters; }
    public void setRadiusMeters(double radiusMeters) { this.radiusMeters = radiusMeters; }
    public int getPoints() { return points; }
    public void setPoints(int points) { this.points = points; }
    public int getBonus() { return bonus; }
    public void setBonus(int bonus) { this.bonus = bonus; }
    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }
    public Instant getCreatedAt() { return createdAt; }
}
