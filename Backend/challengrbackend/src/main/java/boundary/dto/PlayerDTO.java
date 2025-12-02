package boundary.dto;

public record PlayerDTO(
        Long id,
        String name,
        double latitude,
        double longitude
) {}

