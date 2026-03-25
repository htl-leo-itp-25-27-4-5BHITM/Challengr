package boundary.dto;

public class PlayerPointsHistoryDTO {
    public String date;
    public int points;

    public PlayerPointsHistoryDTO() {}

    public PlayerPointsHistoryDTO(String date, int points) {
        this.date = date;
        this.points = points;
    }
}
