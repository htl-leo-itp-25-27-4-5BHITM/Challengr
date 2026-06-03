package boundary.dto;

public record FriendGiftCreateDTO(
        String fromPlayerId,
        String toPlayerId
) {
}