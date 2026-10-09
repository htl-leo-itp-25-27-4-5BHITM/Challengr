package boundary.dto;

public record PlayerDTO(
        String id,
        String name,
        double latitude,
        double longitude,
        int points,
        String rankName,  // Rang der besseren Liga (z.B. für die Ringfarbe auf der Karte)
        String character, // gewählte Spielfigur, null = App-Standard
        int knowledgeTrophies,
        int realLifeTrophies,
        String knowledgeRank,
        String realLifeRank
) {}
