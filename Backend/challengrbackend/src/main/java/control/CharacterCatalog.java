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
        TROPHIES,
        /** Belohnung eines Events (QuestCatalog) – frei, sobald die Event-Belohnung abgeholt wurde; bleibt für immer */
        EVENT
    }

    /** {@code event}: Id des Events bei {@link Requirement#EVENT}, sonst null. */
    public record Entry(String id, String name, Requirement requirement, int required, String event) {
        public Entry(String id, String name, Requirement requirement, int required) {
            this(id, name, requirement, required, null);
        }
    }

    /** Was ein Spieler bisher erreicht hat – daraus ergibt sich, was frei ist. */
    /** events = Figuren-Ids aus abgeholten Event-Belohnungen */
    public record Progress(int wins, int knowledgeWins, int checkins, int trophies, java.util.Set<String> events) {
        public Progress(int wins, int knowledgeWins, int checkins, int trophies) {
            this(wins, knowledgeWins, checkins, trophies, java.util.Set.of());
        }

        public int of(Requirement r) {
            return switch (r) {
                case NONE, EVENT -> 0;
                case WINS -> wins;
                case KNOWLEDGE_WINS -> knowledgeWins;
                case CHECKINS -> checkins;
                case TROPHIES -> trophies;
            };
        }

        /** Fortschritt für eine Figur (Event-Figuren: 1 = Belohnung eines Events mit dieser Figur abgeholt). */
        public int of(Entry e) {
            return e.requirement() == Requirement.EVENT ? (events.contains(e.id()) ? 1 : 0) : of(e.requirement());
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
            new Entry("kage", "Kage", Requirement.TROPHIES, 1400),             // Dueler
            // Event-Belohnungen (QuestCatalog.EVENTS)
            new Entry("crash-dummy", "Crash-Test-Dummy", Requirement.EVENT, 1, "beta")
    );

    private CharacterCatalog() {}

    public static Optional<Entry> find(String id) {
        return ALL.stream().filter(e -> e.id().equals(id)).findFirst();
    }

    public static boolean isUnlocked(Entry entry, Progress progress) {
        return entry.requirement() == Requirement.NONE || progress.of(entry) >= entry.required();
    }
}
