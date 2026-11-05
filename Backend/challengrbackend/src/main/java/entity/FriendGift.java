package entity;

import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "friend_gift")
public class FriendGift {

    public enum Status {
        PENDING,
        CLAIMED
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "from_player_id", nullable = false)
    private String fromPlayerId;

    @Column(name = "to_player_id", nullable = false)
    private String toPlayerId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Status status = Status.PENDING;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "claimed_at")
    private Instant claimedAt;

    /** Sticker, der drin ist: zufällig beim Öffnen ausgelost oder vom Absender ausgesucht */
    @Column(name = "sticker_id", length = 32)
    private String stickerId;

    /** Absender hat einen eigenen Sticker verschenkt (zählt nicht als Tages-Geschenk) */
    @Column(name = "from_collection", columnDefinition = "boolean default false not null")
    private boolean fromCollection = false;

    public String getStickerId() {
        return stickerId;
    }

    public void setStickerId(String stickerId) {
        this.stickerId = stickerId;
    }

    public boolean isFromCollection() {
        return fromCollection;
    }

    public void setFromCollection(boolean fromCollection) {
        this.fromCollection = fromCollection;
    }

    public Long getId() {
        return id;
    }

    public String getFromPlayerId() {
        return fromPlayerId;
    }

    public void setFromPlayerId(String fromPlayerId) {
        this.fromPlayerId = fromPlayerId;
    }

    public String getToPlayerId() {
        return toPlayerId;
    }

    public void setToPlayerId(String toPlayerId) {
        this.toPlayerId = toPlayerId;
    }

    public Status getStatus() {
        return status;
    }

    public void setStatus(Status status) {
        this.status = status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getClaimedAt() {
        return claimedAt;
    }

    public void setClaimedAt(Instant claimedAt) {
        this.claimedAt = claimedAt;
    }
}