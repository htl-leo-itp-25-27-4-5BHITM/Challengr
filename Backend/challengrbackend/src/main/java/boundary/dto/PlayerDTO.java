package boundary.dto;

public record PlayerDTO(
        String id,
        String name,
        double latitude,
        double longitude,
        int points,
        String rankName   // NEU
) {}
