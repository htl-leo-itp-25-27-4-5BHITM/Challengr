package entity;

import jakarta.persistence.*;

import java.time.Instant;

/** Im Dashboard ausgeblendeter OpenStreetMap-Ort – bleibt auch nach dem Neuladen der Kachel weg. */
@Entity
@Table(name = "landmark_hidden")
public class LandmarkHidden {

    @Id
    @Column(length = 40)
    private String id;

    @Column(length = 120)
    private String name;

    @Column(length = 200)
    private String reason;

    @Column(name = "hidden_at", nullable = false)
    private Instant hiddenAt = Instant.now();

    public LandmarkHidden() {}

    public LandmarkHidden(String id, String name, String reason) {
        this.id = id;
        this.name = name;
        this.reason = reason;
    }

    public String getId() { return id; }
    public String getName() { return name; }
    public String getReason() { return reason; }
    public Instant getHiddenAt() { return hiddenAt; }
}
