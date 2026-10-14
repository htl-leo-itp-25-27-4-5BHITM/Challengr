package entity;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "player")
public class Player {

    @Id
    @JsonAlias("keycloakId")
    @Column(length = 128)
    private String id;

    private String name;
    private double longitude;
    private double latitude;

    // NEU: Punkte, Default 0
    private int points = 200;

    /** Trophäen der Liga (Quiz-Show und Real-Life zählen gemeinsam). */
    @Column(columnDefinition = "integer default 200 not null")
    private int trophies = 200;

    /** Höchster je erreichter Trophäen-Stand – Rang-Figuren bleiben frei, auch wenn man wieder abrutscht. */
    @Column(columnDefinition = "integer default 0 not null")
    private int highestTrophies = 200;

    private int consecutiveConflicts = 0;

    @Column(length = 255)
    private String profileStatus;

    @Column(columnDefinition = "TEXT")
    private String badgesJson;

    private Double bestLoudness;

    /**
     * If set and in the future, the player is considered banned.
     * The actual login access is enforced by disabling the Keycloak user.
     */
    private Instant banUntil;

    /** Gewählte Spielfigur (z.B. "sir-brecht"); null = App-Standard. */
    @Column(length = 32)
    private String character;

    @Column(length = 1024)
    private String banReason;

    /** Zuletzt aktiv (Position, Anfrage, WebSocket). Wer länger weg ist, taucht bei "nearby" nicht auf. */
    private Instant lastSeenAt;

    /** "Unsichtbar": weder bei nearby noch per WebSocket für andere sichtbar. */
    @Column(columnDefinition = "boolean default false not null")
    private boolean invisible = false;

    public Player(String name, double longitude, double latitude) {
        this.name = name;
        this.longitude = longitude;
        this.latitude = latitude;
    }

    public Player() {}

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public double getLongitude() {
        return longitude;
    }

    public void setLongitude(double longitude) {
        this.longitude = longitude;
    }

    public double getLatitude() {
        return latitude;
    }

    public void setLatitude(double latitude) {
        this.latitude = latitude;
    }

    // NEU: Punkte-Getter/Setter

    public int getPoints() {
        return points;
    }

    public void setPoints(int points) {
        this.points = points;
    }

    public int getConsecutiveConflicts() {
        return consecutiveConflicts;
    }

    public void setConsecutiveConflicts(int consecutiveConflicts) {
        this.consecutiveConflicts = consecutiveConflicts;
    }

    public String getProfileStatus() {
        return profileStatus;
    }

    public void setProfileStatus(String profileStatus) {
        this.profileStatus = profileStatus;
    }

    public String getBadgesJson() {
        return badgesJson;
    }

    public void setBadgesJson(String badgesJson) {
        this.badgesJson = badgesJson;
    }

    public Double getBestLoudness() {
        return bestLoudness;
    }

    public void setBestLoudness(Double bestLoudness) {
        this.bestLoudness = bestLoudness;
    }

    public Instant getBanUntil() {
        return banUntil;
    }

    public void setBanUntil(Instant banUntil) {
        this.banUntil = banUntil;
    }

    public String getBanReason() {
        return banReason;
    }

    public void setBanReason(String banReason) {
        this.banReason = banReason;
    }

    public String getCharacter() {
        return character;
    }

    public void setCharacter(String character) {
        this.character = character;
    }

    public int getTrophies() {
        return trophies;
    }

    public void setTrophies(int trophies) {
        this.trophies = Math.max(0, trophies); // nie ins Minus
        this.highestTrophies = Math.max(highestTrophies, trophies);
    }

    /** Höchster je erreichter Stand (mindestens der aktuelle – ältere Konten haben hier noch 0). */
    public int getHighestTrophies() {
        return Math.max(highestTrophies, trophies);
    }

    /** Liga-Trophäen für einen Modus: beide Liga-Modi teilen sich einen Stand, Friendly → 0. */
    public int trophiesFor(control.BattleMode mode) {
        return mode.isRanked() ? trophies : 0;
    }

    public void setTrophiesFor(control.BattleMode mode, int value) {
        if (mode.isRanked()) setTrophies(value);
    }

    public Instant getLastSeenAt() {
        return lastSeenAt;
    }

    public void setLastSeenAt(Instant lastSeenAt) {
        this.lastSeenAt = lastSeenAt;
    }

    public boolean isInvisible() {
        return invisible;
    }

    public void setInvisible(boolean invisible) {
        this.invisible = invisible;
    }
}
