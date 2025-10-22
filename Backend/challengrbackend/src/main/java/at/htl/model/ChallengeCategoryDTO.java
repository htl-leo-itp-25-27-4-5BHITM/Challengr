package at.htl.model;

public class ChallengeCategoryDTO {
    public String description;
    public String[] tasks; // Array statt List

    public ChallengeCategoryDTO(String description, String[] tasks) {
        this.description = description;
        this.tasks = tasks;
    }
}
