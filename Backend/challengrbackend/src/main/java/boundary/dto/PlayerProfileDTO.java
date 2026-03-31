package boundary.dto;

import java.util.List;

public record PlayerProfileDTO(
        String status,
        List<String> badges
) {}
