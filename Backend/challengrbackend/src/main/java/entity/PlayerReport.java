package entity;

import jakarta.persistence.*;

import java.time.Instant;

/** B2: Meldung eines Spielers (Grund + optionaler Text), wird im Dashboard bearbeitet. */
@Entity
@Table(name = "player_report")
public class PlayerReport {

    public enum Reason { BELEIDIGUNG, UNPASSENDER_NAME, BELAESTIGUNG, BETRUG, SONSTIGES }
    public enum Status { OPEN, RESOLVED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 128)
    private String reporterId;

    @Column(nullable = false, length = 128)
    private String reportedId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private Reason reason;

    @Column(length = 500)
    private String comment;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.OPEN;

    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public String getReporterId() { return reporterId; }
    public void setReporterId(String reporterId) { this.reporterId = reporterId; }
    public String getReportedId() { return reportedId; }
    public void setReportedId(String reportedId) { this.reportedId = reportedId; }
    public Reason getReason() { return reason; }
    public void setReason(Reason reason) { this.reason = reason; }
    public String getComment() { return comment; }
    public void setComment(String comment) { this.comment = comment; }
    public Status getStatus() { return status; }
    public void setStatus(Status status) { this.status = status; }
    public Instant getCreatedAt() { return createdAt; }
}
