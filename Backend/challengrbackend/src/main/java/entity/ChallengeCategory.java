package entity;

import jakarta.persistence.*;
import java.util.List;

@Entity
@Table(name = "challenge_categories")
public class ChallengeCategory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @Column(length = 1000)
    private String description;

    @OneToMany(mappedBy = "category", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Challenges> challenges;

    public ChallengeCategory() {}

    public ChallengeCategory(String name, String description) {
        this.name = name;
        this.description = description;
    }

    // getters & setters

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public List<Challenges> getChallenges() {
        return challenges;
    }

    public void setChallenges(List<Challenges> challenges) {
        this.challenges = challenges;
    }
}
