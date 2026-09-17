package entity;

import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "player_item", uniqueConstraints = @UniqueConstraint(columnNames = {"player_id", "item_id"}))
public class PlayerItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "player_id", nullable = false, length = 128)
    private String playerId;

    @ManyToOne(optional = false)
    @JoinColumn(name = "item_id", nullable = false)
    private ShopItem item;

    @Column(nullable = false)
    private int quantity = 0;

    @Column(nullable = false)
    private Instant purchasedAt = Instant.now();

    public PlayerItem() {}

    public PlayerItem(String playerId, ShopItem item, int quantity) {
        this.playerId = playerId;
        this.item = item;
        this.quantity = quantity;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getPlayerId() {
        return playerId;
    }

    public void setPlayerId(String playerId) {
        this.playerId = playerId;
    }

    public ShopItem getItem() {
        return item;
    }

    public void setItem(ShopItem item) {
        this.item = item;
    }

    public int getQuantity() {
        return quantity;
    }

    public void setQuantity(int quantity) {
        this.quantity = quantity;
    }

    public Instant getPurchasedAt() {
        return purchasedAt;
    }

    public void setPurchasedAt(Instant purchasedAt) {
        this.purchasedAt = purchasedAt;
    }
}
