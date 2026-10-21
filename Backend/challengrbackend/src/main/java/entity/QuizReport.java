package entity;

import jakarta.persistence.*;

import java.time.Instant;

/** „Frage melden“ aus der Quiz-Show. */
@Entity
@Table(name = "quiz_report", indexes = @Index(columnList = "challenge_id"))
public class QuizReport {

    public enum Reason { FALSCHE_ANTWORT, UNKLAR, TIPPFEHLER, SONSTIGES }
    public enum Status { OPEN, RESOLVED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "challenge_id", nullable = false)
    private Long challengeId;

    @Column(name = "player_id", length = 128, nullable = false)
    private String playerId;

    @Enumerated(EnumType.STRING)
    @Column(length = 24, nullable = false)
    private Reason reason;

    @Column(length = 300)
    private String comment;

    @Enumerated(EnumType.STRING)
    @Column(length = 12, nullable = false)
    private Status status = Status.OPEN;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public QuizReport() {}

    public QuizReport(Long challengeId, String playerId, Reason reason, String comment) {
        this.challengeId = challengeId;
        this.playerId = playerId;
        this.reason = reason;
        this.comment = comment;
    }

    public Long getId() { return id; }
    public Long getChallengeId() { return challengeId; }
    public String getPlayerId() { return playerId; }
    public Reason getReason() { return reason; }
    public String getComment() { return comment; }
    public Status getStatus() { return status; }
    public void setStatus(Status status) { this.status = status; }
    public Instant getCreatedAt() { return createdAt; }
}
