package entity;

import jakarta.persistence.*;

/** Wie oft eine Quizfrage in der Quiz-Show kam und wie sie beantwortet wurde (pro Spieler-Antwort gezählt). */
@Entity
@Table(name = "quiz_stat")
public class QuizStat {

    @Id
    @Column(name = "challenge_id")
    private Long challengeId;

    private long correct;
    private long wrong;
    private long unanswered;

    public QuizStat() {}

    public QuizStat(Long challengeId) { this.challengeId = challengeId; }

    public Long getChallengeId() { return challengeId; }
    public long getCorrect() { return correct; }
    public long getWrong() { return wrong; }
    public long getUnanswered() { return unanswered; }
    public long total() { return correct + wrong + unanswered; }

    public void add(long correct, long wrong, long unanswered) {
        this.correct += correct;
        this.wrong += wrong;
        this.unanswered += unanswered;
    }
}
