package control;

import java.text.Normalizer;
import java.util.List;
import java.util.Locale;

/**
 * B2: einfache Schimpfwortprüfung für Benutzernamen (Deutsch/Englisch).
 * Erkennt auch Leetspeak (1→i, 3→e, 0→o, 4→a, 5→s, @→a) und Trennzeichen ("a.r.s.c.h").
 */
public final class NameFilter {

    private NameFilter() {}

    /** Eindeutig – überall im Namen gesperrt (auch "xxFuckxx"). */
    static final List<String> ANYWHERE = List.of(
            "arschloch", "fotze", "hurensohn", "wichser", "schlampe", "missgeburt", "spasti", "schwuchtel",
            "nigger", "nigga", "kanake", "hitler", "fuck", "bitch", "pussy", "whore", "faggot",
            "retard", "nutte", "scheiss", "scheiß", "titten", "porn", "penis", "vagina", "fick");

    /** Mehrdeutig ("Marschall", "Heilmann", "Scunthorpe") – nur als ganzes Wort gesperrt. */
    static final List<String> WHOLE_WORD = List.of(
            "arsch", "hure", "spast", "nazi", "heil", "shit", "dick", "sex", "slut", "kacke", "wixer",
            "neger", "behindert", "opfer", "cunt");

    public static boolean isOffensive(String name) {
        if (name == null) return false;
        String cleaned = Normalizer.normalize(name.toLowerCase(Locale.ROOT), Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .replace('1', 'i').replace('!', 'i').replace('3', 'e').replace('0', 'o')
                .replace('4', 'a').replace('@', 'a').replace('5', 's').replace('$', 's').replace('7', 't');
        String joined = cleaned.replaceAll("[^a-zß]", "");
        if (ANYWHERE.stream().anyMatch(joined::contains)) return true;
        for (String word : cleaned.split("[^a-zß]+")) {
            if (WHOLE_WORD.contains(word)) return true;
        }
        return WHOLE_WORD.contains(joined);
    }

    /** Ersatzname, wenn der gewünschte Name nicht erlaubt ist. */
    public static String replacementFor(String playerId) {
        String suffix = playerId == null ? "0000" : Integer.toHexString(Math.abs(playerId.hashCode()) % 0xFFFF);
        return "Spieler-" + suffix;
    }
}
