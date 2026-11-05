package boundary.dto;

import entity.FriendGift;

import java.time.Instant;

public record FriendGiftDTO(
        Long id,
        String fromPlayerId,
        String toPlayerId,
        FriendGift.Status status,
        Instant createdAt,
        Instant claimedAt,
        String stickerId, // erst nach dem Öffnen
        boolean fromCollection // vom Absender ausgesucht
) {
}