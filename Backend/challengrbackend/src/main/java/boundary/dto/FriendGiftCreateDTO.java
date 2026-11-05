package boundary.dto;

public record FriendGiftCreateDTO(
        String fromPlayerId,
        String toPlayerId,
        String stickerId // optional: eigenen Sticker verschenken statt Zufalls-Geschenk
) {
}