package control;

import entity.Player;
import entity.QuestClaim;
import entity.StickerStock;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.WebApplicationException;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;

/**
 * Sticker sammeln (Start-Paket, Geschenke, Liga-Siege, Tagesaufgabe, Shop-Paket) und beim Verschicken verbrauchen.
 * Album-Stufen und Sieg-Sticker werden als {@link QuestClaim} gemerkt ("album:5", "sticker-win:<battleId>").
 */
@ApplicationScoped
public class StickerRepository {

    private static final Random RANDOM = new Random();

    @Inject
    EntityManager em;

    @Inject
    FriendshipRepository friendships;

    public List<StickerStock> list(String playerId) {
        return em.createQuery("SELECT s FROM StickerStock s WHERE s.playerId = :p ORDER BY s.id", StickerStock.class)
                .setParameter("p", playerId)
                .getResultList();
    }

    /** Eigene Sammlung; beim allerersten Mal mit Start-Paket, damit man Sticker gleich ausprobieren kann. */
    @Transactional
    public List<StickerStock> listWithStarterPack(String playerId) {
        ensureStarterPack(playerId);
        return list(playerId);
    }

    /** Sticker gutschreiben – das Start-Paket kommt immer zuerst, sonst ginge es durch einen frühen Gewinn verloren. */
    @Transactional
    public StickerStock grant(String playerId, String stickerId) {
        ensureStarterPack(playerId);
        return add(playerId, stickerId);
    }

    @Transactional
    public String grantRandom(String playerId) {
        String id = randomSticker();
        grant(playerId, id);
        return id;
    }

    /** Einen Sticker verbrauchen; gibt zurück, wie viele noch übrig sind, oder -1, wenn keiner mehr da war. */
    @Transactional
    public int consume(String playerId, String stickerId) {
        int updated = em.createQuery(
                        "UPDATE StickerStock s SET s.amount = s.amount - 1 WHERE s.playerId = :p AND s.stickerId = :s AND s.amount > 0")
                .setParameter("p", playerId)
                .setParameter("s", stickerId)
                .executeUpdate();
        if (updated == 0) return -1;
        return em.createQuery("SELECT s.amount FROM StickerStock s WHERE s.playerId = :p AND s.stickerId = :s", Integer.class)
                .setParameter("p", playerId)
                .setParameter("s", stickerId)
                .getSingleResult();
    }

    public String randomSticker() {
        return StickerCatalog.random(RANDOM);
    }

    /** Nach einem Liga-Sieg: mit etwas Glück ein Sticker (pro Battle höchstens einer, pro Tag höchstens ein paar). */
    @Transactional
    public String maybeWinDrop(String playerId, long battleId) {
        return maybeWinDrop(playerId, battleId, RANDOM, false);
    }

    /** rain = Chaos-Stunde „Sticker-Regen“: jeder Sieg bringt einen Sticker, höheres Tageslimit */
    @Transactional
    public String maybeWinDrop(String playerId, long battleId, boolean rain) {
        return maybeWinDrop(playerId, battleId, RANDOM, rain);
    }

    @Transactional
    public String maybeWinDrop(String playerId, long battleId, Random rnd) {
        return maybeWinDrop(playerId, battleId, rnd, false);
    }

    @Transactional
    public String maybeWinDrop(String playerId, long battleId, Random rnd, boolean rain) {
        if (!rain && rnd.nextInt(100) >= StickerCatalog.WIN_DROP_PERCENT) return null;
        String key = "sticker-win:" + battleId;
        var today = QuestService.today();
        long dropsToday = em.createQuery("""
                        SELECT COUNT(c) FROM QuestClaim c
                        WHERE c.playerId = :p AND c.questKey LIKE 'sticker-win:%' AND c.day = :d
                        """, Long.class)
                .setParameter("p", playerId).setParameter("d", today).getSingleResult();
        int limit = rain ? StickerCatalog.RAIN_DROPS_PER_DAY : StickerCatalog.WIN_DROPS_PER_DAY;
        if (dropsToday >= limit || claimed(playerId, key)) return null;
        em.persist(new QuestClaim(playerId, key, today, 0));
        return grantRandom(playerId);
    }

    /** Sticker-Paket für Coins: gibt die neuen Sticker zurück. */
    @Transactional
    public List<String> buyPack(String playerId) {
        Player p = em.find(Player.class, playerId, LockModeType.PESSIMISTIC_WRITE);
        if (p == null) throw new WebApplicationException("Player not found", 404);
        if (p.getPoints() < StickerCatalog.PACK_PRICE) throw new WebApplicationException("Nicht genug Coins", 409);
        p.setPoints(p.getPoints() - StickerCatalog.PACK_PRICE);
        List<String> out = new ArrayList<>();
        for (int i = 0; i < StickerCatalog.PACK_SIZE; i++) out.add(grantRandom(playerId));
        return out;
    }

    /** Wie viele verschiedene Sticker schon gefunden (auch wenn gerade keiner mehr übrig ist) */
    public int foundCount(String playerId) {
        return (int) (long) em.createQuery(
                        "SELECT COUNT(s) FROM StickerStock s WHERE s.playerId = :p AND s.receivedTotal > 0", Long.class)
                .setParameter("p", playerId).getSingleResult();
    }

    public Set<Integer> claimedStages(String playerId) {
        Set<Integer> out = new HashSet<>();
        for (StickerCatalog.Stage stage : StickerCatalog.STAGES) {
            if (claimed(playerId, stageKey(stage))) out.add(stage.found());
        }
        return out;
    }

    /** Album-Stufe abholen: Coins und beim vollen Album der goldene Rahmen. */
    @Transactional
    public void claimStage(String playerId, int found) {
        StickerCatalog.Stage stage = StickerCatalog.STAGES.stream().filter(s -> s.found() == found).findFirst()
                .orElseThrow(() -> new WebApplicationException("Diese Stufe gibt es nicht", 404));
        if (foundCount(playerId) < stage.found()) throw new WebApplicationException("Noch nicht genug Sticker gefunden", 409);
        if (claimed(playerId, stageKey(stage))) throw new WebApplicationException("Schon abgeholt", 409);
        em.persist(new QuestClaim(playerId, stageKey(stage), QuestService.today(), stage.coins()));
        Player p = em.find(Player.class, playerId, LockModeType.PESSIMISTIC_WRITE);
        p.setPoints(p.getPoints() + stage.coins());
        if (stage.goldFrame()) p.setGoldFrame(true);
        em.flush(); // Unique-Constraint greift sofort, falls zweimal gleichzeitig abgeholt wird
    }

    /** Freunde, die diesen Sticker noch nie bekommen haben (für "Freund schenken") */
    public List<String> friendsMissing(String playerId, String stickerId) {
        List<String> friendIds = friendships.listFriendIds(playerId);
        if (friendIds.isEmpty()) return List.of();
        Set<String> have = new HashSet<>(em.createQuery("""
                        SELECT s.playerId FROM StickerStock s
                        WHERE s.playerId IN :ids AND s.stickerId = :s AND s.receivedTotal > 0
                        """, String.class)
                .setParameter("ids", friendIds).setParameter("s", stickerId).getResultList());
        return friendIds.stream().filter(id -> !have.contains(id)).toList();
    }

    private void ensureStarterPack(String playerId) {
        if (!list(playerId).isEmpty()) return;
        for (int i = 0; i < StickerCatalog.STARTER_PACK; i++) {
            add(playerId, randomSticker());
        }
    }

    private StickerStock add(String playerId, String stickerId) {
        StickerStock stock = em.createQuery(
                        "SELECT s FROM StickerStock s WHERE s.playerId = :p AND s.stickerId = :s", StickerStock.class)
                .setParameter("p", playerId)
                .setParameter("s", stickerId)
                .getResultStream().findFirst().orElse(null);
        if (stock == null) {
            stock = new StickerStock(playerId, stickerId);
            em.persist(stock);
        }
        stock.receive();
        return stock;
    }

    private boolean claimed(String playerId, String key) {
        return em.createQuery("SELECT COUNT(c) FROM QuestClaim c WHERE c.playerId = :p AND c.questKey = :k", Long.class)
                .setParameter("p", playerId).setParameter("k", key).getSingleResult() > 0;
    }

    private static String stageKey(StickerCatalog.Stage stage) {
        return "album:" + stage.found();
    }
}
