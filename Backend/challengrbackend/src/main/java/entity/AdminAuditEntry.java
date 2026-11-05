package entity;

import jakarta.persistence.*;

import java.time.Instant;

/** Protokoll: welcher Admin wann was geändert hat (Trophäen, Coins, Fragen, Events, Orte …). */
@Entity
@Table(name = "admin_audit", indexes = {@Index(columnList = "player_id"), @Index(columnList = "created_at")})
public class AdminAuditEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "admin_id", length = 128)
    private String adminId;

    @Column(name = "admin_name", length = 128)
    private String adminName;

    /** z. B. TROPHIES, COINS, QUIZ_EDIT, EVENT_SAVE, SPOT_HIDE, BACKUP */
    @Column(length = 32, nullable = false)
    private String action;

    /** betroffener Spieler (falls es um einen geht) */
    @Column(name = "player_id", length = 128)
    private String playerId;

    @Column(name = "player_name", length = 128)
    private String playerName;

    @Column(name = "old_value", length = 255)
    private String oldValue;

    @Column(name = "new_value", length = 255)
    private String newValue;

    @Column(length = 500)
    private String reason;

    public AdminAuditEntry() {}

    public AdminAuditEntry(String adminId, String adminName, String action, String playerId, String playerName,
                           String oldValue, String newValue, String reason) {
        this.adminId = adminId;
        this.adminName = adminName;
        this.action = action;
        this.playerId = playerId;
        this.playerName = playerName;
        this.oldValue = cut(oldValue, 255);
        this.newValue = cut(newValue, 255);
        this.reason = cut(reason, 500);
    }

    private static String cut(String s, int max) {
        return s == null || s.length() <= max ? s : s.substring(0, max);
    }

    public Long getId() { return id; }
    public Instant getCreatedAt() { return createdAt; }
    public String getAdminId() { return adminId; }
    public String getAdminName() { return adminName; }
    public String getAction() { return action; }
    public String getPlayerId() { return playerId; }
    public String getPlayerName() { return playerName; }
    public String getOldValue() { return oldValue; }
    public String getNewValue() { return newValue; }
    public String getReason() { return reason; }
}
