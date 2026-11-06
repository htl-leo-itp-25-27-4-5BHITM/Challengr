package entity;

import jakarta.persistence.*;

import java.time.Instant;

/** Gerät für Push-Benachrichtigungen (APNs-Token). Ein Spieler kann mehrere Geräte haben, ein Token gehört genau einem Spieler. */
@Entity
@Table(name = "push_token",
        uniqueConstraints = @UniqueConstraint(columnNames = "token"),
        indexes = @Index(columnList = "player_id"))
public class PushToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "player_id", length = 128, nullable = false)
    private String playerId;

    @Column(length = 200, nullable = false)
    private String token;

    /** Bundle-ID der App (TestFlight und Entwickler-Build haben verschiedene) */
    @Column(length = 100, nullable = false)
    private String topic;

    /** Entwickler-Build: Apples Test-Server statt des echten */
    @Column(columnDefinition = "boolean default false not null")
    private boolean sandbox;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    public PushToken() {}

    public PushToken(String playerId, String token, String topic, boolean sandbox) {
        this.playerId = playerId;
        this.token = token;
        this.topic = topic;
        this.sandbox = sandbox;
    }

    public Long getId() { return id; }
    public String getPlayerId() { return playerId; }
    public void setPlayerId(String playerId) { this.playerId = playerId; }
    public String getToken() { return token; }
    public String getTopic() { return topic; }
    public void setTopic(String topic) { this.topic = topic; }
    public boolean isSandbox() { return sandbox; }
    public void setSandbox(boolean sandbox) { this.sandbox = sandbox; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
