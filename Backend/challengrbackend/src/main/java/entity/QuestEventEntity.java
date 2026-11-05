package entity;

import jakarta.persistence.*;

import java.time.Instant;
import java.time.LocalDate;

/** Ein Event (z. B. Beta, Halloween) – im Dashboard angelegt. Die Challenges stehen als JSON in tasks_json. */
@Entity
@Table(name = "quest_event")
public class QuestEventEntity {

    @Id
    @Column(length = 32)
    private String id;

    @Column(nullable = false, length = 80)
    private String title;

    @Column(length = 160)
    private String subtitle;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    @Column(name = "reward_character", length = 32)
    private String rewardCharacter;

    @Column(name = "reward_coins")
    private int rewardCoins;

    @Column(name = "tasks_json", columnDefinition = "TEXT", nullable = false)
    private String tasksJson;

    @Column(name = "updated_at")
    private Instant updatedAt = Instant.now();

    public QuestEventEntity() {}

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getSubtitle() { return subtitle; }
    public void setSubtitle(String subtitle) { this.subtitle = subtitle; }
    public LocalDate getStartDate() { return startDate; }
    public void setStartDate(LocalDate startDate) { this.startDate = startDate; }
    public LocalDate getEndDate() { return endDate; }
    public void setEndDate(LocalDate endDate) { this.endDate = endDate; }
    public String getRewardCharacter() { return rewardCharacter; }
    public void setRewardCharacter(String rewardCharacter) { this.rewardCharacter = rewardCharacter; }
    public int getRewardCoins() { return rewardCoins; }
    public void setRewardCoins(int rewardCoins) { this.rewardCoins = rewardCoins; }
    public String getTasksJson() { return tasksJson; }
    public void setTasksJson(String tasksJson) { this.tasksJson = tasksJson; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
