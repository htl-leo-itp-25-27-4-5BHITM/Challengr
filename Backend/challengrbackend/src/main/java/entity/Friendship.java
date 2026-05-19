package entity;

import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(
        name = "friendship",
        uniqueConstraints = {
                @UniqueConstraint(columnNames = {"player_a_id", "player_b_id"})
        }
)
public class Friendship {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "player_a_id", nullable = false)
    private String playerAId;

    @Column(name = "player_b_id", nullable = false)
    private String playerBId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public Long getId() {
        return id;
    }

    public String getPlayerAId() {
        return playerAId;
    }

    public void setPlayerAId(String playerAId) {
        this.playerAId = playerAId;
    }

    public String getPlayerBId() {
        return playerBId;
    }

    public void setPlayerBId(String playerBId) {
        this.playerBId = playerBId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }
}
