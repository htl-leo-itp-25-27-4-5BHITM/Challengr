package entity;

import jakarta.persistence.*;

import java.time.Instant;

/** B2: Spieler A hat Spieler B blockiert – beide sehen und erreichen sich nicht mehr. */
@Entity
@Table(name = "player_block",
        uniqueConstraints = @UniqueConstraint(columnNames = {"blockerId", "blockedId"}))
public class PlayerBlock {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 128)
    private String blockerId;

    @Column(nullable = false, length = 128)
    private String blockedId;

    private Instant createdAt = Instant.now();

    public PlayerBlock() {}

    public PlayerBlock(String blockerId, String blockedId) {
        this.blockerId = blockerId;
        this.blockedId = blockedId;
    }

    public Long getId() { return id; }
    public String getBlockerId() { return blockerId; }
    public String getBlockedId() { return blockedId; }
    public Instant getCreatedAt() { return createdAt; }
}
