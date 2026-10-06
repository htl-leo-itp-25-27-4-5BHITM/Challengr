package entity;

import jakarta.persistence.*;

import java.time.Instant;
import java.time.LocalDate;

/** Ein Check-in eines Spielers an einem Hotspot – höchstens einer pro Spieler, Hotspot und Tag. */
@Entity
@Table(name = "hotspot_checkin",
        uniqueConstraints = @UniqueConstraint(columnNames = {"player_id", "hotspot_id", "checkin_day"}))
public class HotspotCheckin {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "player_id", nullable = false, length = 128)
    private String playerId;

    @Column(name = "hotspot_id", nullable = false, length = 64)
    private String hotspotId;

    /** Kalendertag (Europe/Vienna). Spaltenname nicht "day" – das ist in H2 reserviert. */
    @Column(name = "checkin_day", nullable = false)
    private LocalDate day;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    /** Vergebene Punkte inkl. Bonus. */
    private int points;

    /** Erster Check-in des Tages an diesem Hotspot. */
    @Column(name = "first_of_day")
    private boolean firstOfDay;

    public Long getId() { return id; }
    public String getPlayerId() { return playerId; }
    public void setPlayerId(String playerId) { this.playerId = playerId; }
    public String getHotspotId() { return hotspotId; }
    public void setHotspotId(String hotspotId) { this.hotspotId = hotspotId; }
    public LocalDate getDay() { return day; }
    public void setDay(LocalDate day) { this.day = day; }
    public Instant getCreatedAt() { return createdAt; }
    public int getPoints() { return points; }
    public void setPoints(int points) { this.points = points; }
    public boolean isFirstOfDay() { return firstOfDay; }
    public void setFirstOfDay(boolean firstOfDay) { this.firstOfDay = firstOfDay; }
}
