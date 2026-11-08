package entity;

import jakarta.persistence.*;

/** Liga-Siege eines Spielers mit einer Figur – daraus ergibt sich die Figuren-Stufe (control.CharacterLevel). */
@Entity
@Table(name = "character_progress",
        uniqueConstraints = @UniqueConstraint(columnNames = {"player_id", "character_id"}),
        indexes = @Index(columnList = "player_id"))
public class CharacterProgress {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "player_id", length = 128, nullable = false)
    private String playerId;

    @Column(name = "character_id", length = 64, nullable = false)
    private String character;

    private int wins;

    public CharacterProgress() {}

    public CharacterProgress(String playerId, String character) {
        this.playerId = playerId;
        this.character = character;
    }

    public String getPlayerId() { return playerId; }
    public String getCharacter() { return character; }
    public int getWins() { return wins; }
    public void setWins(int wins) { this.wins = wins; }
}
