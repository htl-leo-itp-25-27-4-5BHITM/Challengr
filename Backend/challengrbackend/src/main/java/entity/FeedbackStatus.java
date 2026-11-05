package entity;

import jakarta.persistence.*;

import java.time.Instant;

/** "Erledigt"-Haken für TestFlight-Feedback (das Feedback selbst liegt bei Apple). */
@Entity
@Table(name = "feedback_status")
public class FeedbackStatus {

    /** ID der Feedback-Meldung in App Store Connect */
    @Id
    @Column(length = 64)
    private String feedbackId;

    @Column(columnDefinition = "boolean default false not null")
    private boolean done;

    private Instant doneAt;

    @Column(length = 128)
    private String doneBy;

    public FeedbackStatus() {}

    public FeedbackStatus(String feedbackId) {
        this.feedbackId = feedbackId;
    }

    public String getFeedbackId() { return feedbackId; }
    public boolean isDone() { return done; }
    public Instant getDoneAt() { return doneAt; }
    public String getDoneBy() { return doneBy; }

    public void mark(boolean done, String by) {
        this.done = done;
        this.doneAt = done ? Instant.now() : null;
        this.doneBy = done ? by : null;
    }
}
