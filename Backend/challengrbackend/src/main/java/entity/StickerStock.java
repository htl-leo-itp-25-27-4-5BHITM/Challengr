package entity;

import jakarta.persistence.*;

/**
 * Sticker-Sammlung eines Spielers: wie oft er einen Sticker noch schicken kann
 * und wie oft er ihn insgesamt bekommen hat (Album: "gefunden", auch wenn alle verschickt sind).
 */
@Entity
@Table(name = "sticker_stock",
        uniqueConstraints = @UniqueConstraint(columnNames = {"player_id", "sticker_id"}),
        indexes = @Index(columnList = "player_id"))
public class StickerStock {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "player_id", length = 128, nullable = false)
    private String playerId;

    @Column(name = "sticker_id", length = 32, nullable = false)
    private String stickerId;

    /** So oft kann er ihn noch schicken */
    @Column(nullable = false)
    private int amount;

    @Column(name = "received_total", nullable = false)
    private int receivedTotal;

    public StickerStock() {}

    public StickerStock(String playerId, String stickerId) {
        this.playerId = playerId;
        this.stickerId = stickerId;
    }

    public void receive() {
        amount++;
        receivedTotal++;
    }

    public Long getId() { return id; }
    public String getPlayerId() { return playerId; }
    public String getStickerId() { return stickerId; }
    public int getAmount() { return amount; }
    public int getReceivedTotal() { return receivedTotal; }
}
