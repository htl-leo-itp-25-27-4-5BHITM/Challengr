package control;

import java.util.List;
import java.util.Optional;

/**
 * Alle Spielfiguren und wie sie freigeschaltet werden.
 * Die Ids müssen zu GameCharacter in der App passen.
 */
public final class CharacterCatalog {

    /** Wofür man eine Figur bekommt. */
    public enum Requirement {
        /** von Anfang an frei */
        NONE,
        /** gewonnene Battles */
        WINS,
        /** gewonnene Wissens-Battles */
        KNOWLEDGE_WINS,
        /** Check-ins an Hotspots */
        CHECKINS,
        /** Rang auf der Trophy Road: höchster je erreichter Trophäen-Stand (required = Untergrenze des Rangs) */
        TROPHIES
    }

    public record Entry(String id, String name, Requirement requirement, int required) {}

    /** Was ein Spieler bisher erreicht hat – daraus ergibt sich, was frei ist. */
    public record Progress(int wins, int knowledgeWins, int checkins, int trophies) {
        public int of(Requirement r) {
            return switch (r) {
                case NONE -> 0;
                case WINS -> wins;
                case KNOWLEDGE_WINS -> knowledgeWins;
                case CHECKINS -> checkins;
                case TROPHIES -> trophies;
            };
        }
    }

    public static final List<Entry> ALL = List.of(
            new Entry("junge", "Junge", Requirement.NONE, 0),
            new Entry("maedchen", "Mädchen", Requirement.NONE, 0),
            new Entry("sir-brecht", "Sir Brecht", Requirement.WINS, 1),
            new Entry("ragnar", "Ragnar", Requirement.WINS, 3),
            new Entry("merlo", "Merlo", Requirement.KNOWLEDGE_WINS, 3),
            new Entry("lyra", "Lyra", Requirement.CHECKINS, 5),
            // Rang-Belohnungen der Trophy Road (Grenzen wie in reference-data.sql)
            new Entry("kaeptn-rex", "Käpt'n Rex", Requirement.TROPHIES, 350),  // Contender
            new Entry("hayato", "Hayato", Requirement.TROPHIES, 600),          // Tryhard
            new Entry("kai", "Kai", Requirement.TROPHIES, 950),                // Brawler
            new Entry("kage", "Kage", Requirement.TROPHIES, 1400)              // Dueler
    );

    private CharacterCatalog() {}

    public static Optional<Entry> find(String id) {
        return ALL.stream().filter(e -> e.id().equals(id)).findFirst();
    }

    public static boolean isUnlocked(Entry entry, Progress progress) {
        return entry.requirement() == Requirement.NONE || progress.of(entry.requirement()) >= entry.required();
    }
}
