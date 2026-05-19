package boundary.dto;

import entity.FriendRequest;

import java.time.Instant;

public record FriendRequestDTO(
        Long id,
        String fromPlayerId,
        String toPlayerId,
        FriendRequest.Status status,
        Instant createdAt
) {
}
