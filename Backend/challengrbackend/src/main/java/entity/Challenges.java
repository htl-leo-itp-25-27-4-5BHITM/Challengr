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

    // NEU: Multiple-Choice-Felder (für Wissen)
    @Column(name = "option_a")
    private String optionA;

    @Column(name = "option_b")
    private String optionB;

    @Column(name = "option_c")
    private String optionC;

    @Column(name = "option_d")
    private String optionD;

    @Column(name = "correct_index")
    private Integer correctIndex; // 0–3 für Wissen

    public Challenges() {}

    public Challenges(String text, ChallengeCategory challengeCategory) {
        this.text = text;
        this.challengeCategory = challengeCategory;
    }

    // Getter & Setter

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }

    public String getText() { return text; }
    public void setText(String text) { this.text = text; }

    public ChallengeCategory getChallengeCategory() { return challengeCategory; }
    public void setChallengeCategory(ChallengeCategory challengeCategory) { this.challengeCategory = challengeCategory; }

    public String getOptionA() { return optionA; }
    public void setOptionA(String optionA) { this.optionA = optionA; }

    public String getOptionB() { return optionB; }
    public void setOptionB(String optionB) { this.optionB = optionB; }

    public String getOptionC() { return optionC; }
    public void setOptionC(String optionC) { this.optionC = optionC; }

    public String getOptionD() { return optionD; }
    public void setOptionD(String optionD) { this.optionD = optionD; }

    public Integer getCorrectIndex() { return correctIndex; }
    public void setCorrectIndex(Integer correctIndex) { this.correctIndex = correctIndex; }
}
