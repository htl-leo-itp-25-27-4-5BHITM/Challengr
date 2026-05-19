package boundary.dto;

public record FriendRequestCreateDTO(
        String fromPlayerId,
        String toPlayerId
) {
}
