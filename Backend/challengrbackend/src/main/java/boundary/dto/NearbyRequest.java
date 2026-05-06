package boundary.dto;

public record NearbyRequest(
        String playerId,
        double latitude,
        double longitude,
        double radius // in Metern
) {}

