package entity;

import jakarta.persistence.*;

import java.time.LocalDate;

/** An welchen Tagen ein Spieler aktiv war (ein Eintrag pro Spieler und Tag) – nur für die Statistik im Dashboard. */
@Entity
@Table(name = "player_activity",
        uniqueConstraints = @UniqueConstraint(columnNames = {"player_id", "activity_day"}),
        indexes = @Index(columnList = "activity_day"))
public class PlayerActivity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "player_id", length = 128, nullable = false)
    private String playerId;

    @Column(name = "activity_day", nullable = false)   // "day" ist in manchen Datenbanken reserviert
    private LocalDate day;

    public PlayerActivity() {}

    public PlayerActivity(String playerId, LocalDate day) {
        this.playerId = playerId;
        this.day = day;
    }

    public String getPlayerId() { return playerId; }
    public LocalDate getDay() { return day; }
}
