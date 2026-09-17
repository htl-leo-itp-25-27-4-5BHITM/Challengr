package entity;

import jakarta.persistence.*;

@Entity
@Table(name = "shop_item")
public class ShopItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Stable identifier used by clients to request a purchase (independent of DB id).
    @Column(nullable = false, unique = true, length = 64)
    private String code;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String imageName;

    @Column(nullable = false)
    private int price;

    @Column(nullable = false)
    private String rarity;

    public ShopItem() {}

    public ShopItem(String code, String name, String imageName, int price, String rarity) {
        this.code = code;
        this.name = name;
        this.imageName = imageName;
        this.price = price;
        this.rarity = rarity;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getImageName() {
        return imageName;
    }

    public void setImageName(String imageName) {
        this.imageName = imageName;
    }

    public int getPrice() {
        return price;
    }

    public void setPrice(int price) {
        this.price = price;
    }

    public String getRarity() {
        return rarity;
    }

    public void setRarity(String rarity) {
        this.rarity = rarity;
    }
}
