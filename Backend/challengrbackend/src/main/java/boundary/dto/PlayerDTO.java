package boundary.dto;

public record PlayerDTO(
        Long id,
        String name,
        double latitude,
        double longitude,
        int points,
        String rankName   // NEU
) {}
