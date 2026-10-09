package control;

/**
 * Spielmodus eines Battles (gespeichert in Battle.type).
 * - FRIENDLY: es geht um nichts, Kategorie und Challenge frei wählbar
 * - RANKED_KNOWLEDGE: Liga Wissen, Quiz-Show mit 4 Fragen, Wissen-Trophäen
 * - RANKED_REALLIFE: Liga Real-Life, zufällige vom Handy gemessene Challenge, Real-Life-Trophäen
 */
public enum BattleMode {
    FRIENDLY, RANKED_KNOWLEDGE, RANKED_REALLIFE;

    /** Kategorie, aus der die Liga Real-Life zieht: nur Challenges, die das Handy misst. */
    public static final String REALLIFE_CATEGORY = "iPhone";
    public static final String KNOWLEDGE_CATEGORY = "Wissen";

    /** Unbekannt oder fehlend (alte Apps) → Friendly, dabei geht es um nichts. */
    public static BattleMode from(String value) {
        if (value == null) return FRIENDLY;
        for (BattleMode m : values()) {
            if (m.name().equalsIgnoreCase(value)) return m;
        }
        return FRIENDLY;
    }

    public boolean isRanked() {
        return this != FRIENDLY;
    }
}
