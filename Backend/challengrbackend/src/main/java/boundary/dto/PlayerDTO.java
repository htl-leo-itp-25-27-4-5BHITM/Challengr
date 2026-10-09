package boundary.dto;

/**
 * Spieler für die App. Koordinaten: beim eigenen Konto genau, bei "nearby" gerundet,
 * sonst (fremdes Profil) gar nicht – dann null.
 */
public record PlayerDTO(
        String id,
        String name,
        Double latitude,
        Double longitude,
        int points,
        String rankName,  // Liga-Rang nach Trophäen (z.B. für die Ringfarbe auf der Karte)
        String character, // gewählte Spielfigur, null = App-Standard
        int trophies,     // Liga-Trophäen (Quiz-Show und Real-Life gemeinsam)
        Boolean invisible // nur beim eigenen Konto gesetzt
) {}
