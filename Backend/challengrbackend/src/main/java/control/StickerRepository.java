package control;

import entity.StickerStock;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.util.List;
import java.util.Random;

/** Sticker sammeln (Geschenke, Start-Paket) und beim Verschicken verbrauchen. */
@ApplicationScoped
public class StickerRepository {

    private static final Random RANDOM = new Random();

    @Inject
    EntityManager em;

    public List<StickerStock> list(String playerId) {
        return em.createQuery("SELECT s FROM StickerStock s WHERE s.playerId = :p ORDER BY s.id", StickerStock.class)
                .setParameter("p", playerId)
                .getResultList();
    }

    /** Eigene Sammlung; beim allerersten Mal mit Start-Paket, damit man Sticker gleich ausprobieren kann. */
    @Transactional
    public List<StickerStock> listWithStarterPack(String playerId) {
        if (list(playerId).isEmpty()) {
            for (int i = 0; i < StickerCatalog.STARTER_PACK; i++) {
                grant(playerId, randomSticker());
            }
        }
        return list(playerId);
    }

    @Transactional
    public StickerStock grant(String playerId, String stickerId) {
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
}
