package control;

import java.util.List;
import java.util.Optional;

/**
 * Alle Spielfiguren und wann sie freigeschaltet werden.
 * Die Ids müssen zu GameCharacter in der App passen.
 */
public final class CharacterCatalog {

    /** @param winsRequired gewonnene Battles, ab denen die Figur wählbar ist */
    public record Entry(String id, String name, int winsRequired) {}

    public static final List<Entry> ALL = List.of(
            new Entry("sir-brecht", "Sir Brecht", 0),
            new Entry("ragnar", "Ragnar", 0),
            new Entry("hayato", "Hayato", 3)
    );

    private CharacterCatalog() {}

    public static Optional<Entry> find(String id) {
        return ALL.stream().filter(e -> e.id().equals(id)).findFirst();
    }

    public static boolean isUnlocked(String id, int wins) {
        return find(id).map(e -> wins >= e.winsRequired()).orElse(false);
    }
}
