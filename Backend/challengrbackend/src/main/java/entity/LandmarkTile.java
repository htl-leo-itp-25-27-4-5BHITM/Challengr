package entity;

import jakarta.persistence.*;

import java.time.Instant;

/** Welche Kachel (ca. 2 × 2 km) schon aus OpenStreetMap geladen wurde – damit nicht jeder Aufruf neu fragt. */
@Entity
@Table(name = "landmark_tile")
public class LandmarkTile {

    @Id
    @Column(name = "tile_key", length = 24)
    private String key;

    @Column(name = "fetched_at", nullable = false)
    private Instant fetchedAt;

    private int count;

    public LandmarkTile() {}

    public LandmarkTile(String key, Instant fetchedAt, int count) {
        this.key = key;
        this.fetchedAt = fetchedAt;
        this.count = count;
    }

    public String getKey() { return key; }
    public Instant getFetchedAt() { return fetchedAt; }
    public void setFetchedAt(Instant fetchedAt) { this.fetchedAt = fetchedAt; }
    public int getCount() { return count; }
    public void setCount(int count) { this.count = count; }
}
