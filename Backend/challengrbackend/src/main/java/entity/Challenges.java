package entity;

import jakarta.persistence.*;

@Entity
@Table(name = "challenges")
public class Challenges {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private long id;

    @Column(length = 500)
    private String text;

    @ManyToOne
    @JoinColumn(name = "category_id")
    private ChallengeCategory challengeCategory;

    public Challenges() {}

    public Challenges(String text, ChallengeCategory challengeCategory) {
        this.text = text;
        this.challengeCategory = challengeCategory;
    }

    // gettes & setters

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }

    public ChallengeCategory getChallengeCategory() {
        return challengeCategory;
    }

    public void setChallengeCategory(ChallengeCategory challengeCategory) {
        this.challengeCategory = challengeCategory;
    }
}
