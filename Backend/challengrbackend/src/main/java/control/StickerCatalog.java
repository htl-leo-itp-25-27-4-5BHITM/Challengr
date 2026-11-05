package control;

import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;

/**
 * Sticker aus dem Fight-Video – gleiche IDs wie in der App (Stickers.all).
 * Man sammelt sie aus Geschenken und verbraucht einen pro Verschicken.
 */
public final class StickerCatalog {

    private StickerCatalog() {}

    /** Sticker-ID → Ersatz-Emoji für alte App-Versionen; jedes steht auch in GameSocket.EMOTES. */
    public static final Map<String, String> FALLBACK = Map.ofEntries(
            Map.entry("aura", "🔥"), Map.entry("gogogo", "⚡"), Map.entry("1hit", "🥊"), Map.entry("locked", "😤"),
            Map.entry("mvp", "🏆"), Map.entry("schularbeit", "😴"), Map.entry("vorbei", "💪"), Map.entry("farming", "😎"),
            Map.entry("skillissue", "😂"), Map.entry("oida", "😤"), Map.entry("minusaura", "😅"), Map.entry("brodachte", "😂"),
            Map.entry("diskussion", "👑"), Map.entry("baba", "👋"), Map.entry("hue", "🤔"), Map.entry("crazy", "🤯"),
            Map.entry("1v1", "🥊"), Map.entry("bigbrain", "🧠"), Map.entry("zauber", "⚡"), Map.entry("naechste", "👀"));

    /** Die bewegten Sticker – im Geschenk seltener. */
    public static final Set<String> ANIMATED = Set.of("aura", "gogogo", "1hit", "oida", "crazy", "farming");

    /** Einmal für jeden Spieler zum Ausprobieren. */
    public static final int STARTER_PACK = 3;

    /** Liga-Sieg: so oft (in Prozent) springt ein Sticker raus, höchstens so oft am Tag – sonst könnte man farmen. */
    public static final int WIN_DROP_PERCENT = 25;
    public static final int WIN_DROPS_PER_DAY = 3;

    /** Sticker-Paket im Shop */
    public static final int PACK_SIZE = 3;
    public static final int PACK_PRICE = 100;

    /** Album-Stufe: ab so vielen gefundenen Stickern gibt's Coins, beim vollen Album den goldenen Rahmen. */
    public record Stage(int found, int coins, boolean goldFrame) {}

    public static final List<Stage> STAGES = List.of(
            new Stage(5, 50, false), new Stage(10, 100, false), new Stage(15, 150, false), new Stage(20, 0, true));

    private static final List<String> IDS = FALLBACK.keySet().stream().sorted().toList();

    /** Bewegte Sticker kommen 1 zu 3 seltener als normale. */
    static int weight(String id) {
        return ANIMATED.contains(id) ? 1 : 3;
    }

    /** Zufälliger Sticker für ein Geschenk oder das Start-Paket. */
    public static String random(Random rnd) {
        int r = rnd.nextInt(IDS.stream().mapToInt(StickerCatalog::weight).sum());
        for (String id : IDS) {
            r -= weight(id);
            if (r < 0) return id;
        }
        return IDS.get(IDS.size() - 1);
    }
}
