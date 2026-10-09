package boundary.dto;

public record PlayerDTO(
        String id,
        String name,
        double latitude,
        double longitude,
        int points,
        String rankName,  // Liga-Rang nach Trophäen (z.B. für die Ringfarbe auf der Karte)
        String character, // gewählte Spielfigur, null = App-Standard
        int trophies      // Liga-Trophäen (Quiz-Show und Real-Life gemeinsam)
) {}
