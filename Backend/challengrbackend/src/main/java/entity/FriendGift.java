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