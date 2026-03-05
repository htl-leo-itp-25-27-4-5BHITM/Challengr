package boundary.dto;

import java.util.List;

public record ChallengeDTO(
        long id,
        String text,
        String category,
        List<String> choices,   // nur für Wissen
        Integer correctIndex    // Index in choices (0–3)
) {}
