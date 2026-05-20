package boundary.dto;

import java.util.List;

/**
 * Payload for creating a new challenge via the admin dashboard.
 *
 * category: category name (e.g. Fitness, Mutprobe, Wissen, iPhone, Customer)
 * text:     challenge text
 * choices + correctIndex: only for category "Wissen"
 */
public record ChallengeCreateDTO(
        String text,
        String category,
        List<String> choices,
        Integer correctIndex
) {
}
