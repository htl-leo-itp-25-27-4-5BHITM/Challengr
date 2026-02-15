package entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
public class Battle {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "from_player_id", nullable = false)
    private Player fromPlayer;

    @ManyToOne
    @JoinColumn(name = "to_player_id", nullable = false)
    private Player toPlayer;

    @ManyToOne
    @JoinColumn(name = "challenge_id", nullable = false)
    private Challenges challenge;

    @ManyToOne
    @JoinColumn(name = "category_id", nullable = false)
    private ChallengeCategory category;

    // NEW: Gewinner des Battles
    @ManyToOne
    @JoinColumn(name = "winner_id")
    private Player winner;

    private String status;   // REQUESTED, ACCEPTED, DONE, ...
    private String type;     // NORMAL, ...

    private Integer winnerPointsDelta;
    private Integer loserPointsDelta;


    private LocalDateTime createdAt = LocalDateTime.now();

    // --- Getter/Setter ---

    public Long getId() {
        return id;
    }

    public Player getFromPlayer() {
        return fromPlayer;
    }

    public void setFromPlayer(Player fromPlayer) {
        this.fromPlayer = fromPlayer;
    }

    public Player getToPlayer() {
        return toPlayer;
    }

    public void setToPlayer(Player toPlayer) {
        this.toPlayer = toPlayer;
    }

    public Challenges getChallenge() {
        return challenge;
    }

    public void setChallenge(Challenges challenge) {
        this.challenge = challenge;
    }

    public ChallengeCategory getCategory() {
        return category;
    }

    public void setCategory(ChallengeCategory category) {
        this.category = category;
    }

    public Player getWinner() {
        return winner;
    }

    public void setWinner(Player winner) {
        this.winner = winner;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public Integer getWinnerPointsDelta() {
        return winnerPointsDelta;
    }

    public void setWinnerPointsDelta(Integer winnerPointsDelta) {
        this.winnerPointsDelta = winnerPointsDelta;
    }

    public Integer getLoserPointsDelta() {
        return loserPointsDelta;
    }

    public void setLoserPointsDelta(Integer loserPointsDelta) {
        this.loserPointsDelta = loserPointsDelta;
    }
}
