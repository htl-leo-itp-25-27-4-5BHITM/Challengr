package boundary.dto;

public record NearbyRequest(
        Long playerId,
        double latitude,
        double longitude,
        double radius // in Metern
) {}

