package entity;

import jakarta.persistence.*;

import java.time.Instant;
import java.time.LocalDate;

/**
 * Abgeholte Belohnung: eine Tagesaufgabe ("daily:2026-10-20:WIN_BATTLE") oder ein Event ("event:beta").
 * Pro Spieler und Schlüssel nur einmal – so kann nichts doppelt abgeholt werden.
 */
@Entity
@Table(name = "quest_claim",
        uniqueConstraints = @UniqueConstraint(columnNames = {"player_id", "quest_key"}),
        indexes = @Index(columnList = "player_id"))
public class QuestClaim {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "player_id", length = 128, nullable = false)
    private String playerId;

    @Column(name = "quest_key", length = 96, nullable = false)
    private String questKey;

    /** Spieltag (Wiener Zeit), an dem abgeholt wurde */
    @Column(name = "claim_day", nullable = false)
    private LocalDate day;

    private int coins;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public QuestClaim() {}

    public QuestClaim(String playerId, String questKey, LocalDate day, int coins) {
        this.playerId = playerId;
        this.questKey = questKey;
        this.day = day;
        this.coins = coins;
    }

    public String getPlayerId() { return playerId; }
    public String getQuestKey() { return questKey; }
    public LocalDate getDay() { return day; }
    public int getCoins() { return coins; }
}
