package control;

import entity.PlayerItem;
import entity.ShopItem;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.util.List;

@ApplicationScoped
public class ShopRepository {

    @Inject
    EntityManager em;

    public List<ShopItem> getAllItems() {
        return em.createQuery("SELECT s FROM ShopItem s ORDER BY s.price ASC", ShopItem.class)
                .getResultList();
    }

    public ShopItem findByCode(String code) {
        if (code == null || code.isBlank()) {
            return null;
        }
        return em.createQuery("SELECT s FROM ShopItem s WHERE s.code = :code", ShopItem.class)
                .setParameter("code", code)
                .getResultStream()
                .findFirst()
                .orElse(null);
    }

    public List<PlayerItem> getOwnedItems(String playerId) {
        return em.createQuery("SELECT pi FROM PlayerItem pi WHERE pi.playerId = :playerId", PlayerItem.class)
                .setParameter("playerId", playerId)
                .getResultList();
    }

    @Transactional
    public PlayerItem addOrIncrement(String playerId, ShopItem item) {
        PlayerItem existing = em.createQuery(
                        "SELECT pi FROM PlayerItem pi WHERE pi.playerId = :playerId AND pi.item = :item",
                        PlayerItem.class
                )
                .setParameter("playerId", playerId)
                .setParameter("item", item)
                .getResultStream()
                .findFirst()
                .orElse(null);

        if (existing != null) {
            existing.setQuantity(existing.getQuantity() + 1);
            existing.setPurchasedAt(java.time.Instant.now());
            return existing;
        }

        PlayerItem playerItem = new PlayerItem(playerId, item, 1);
        em.persist(playerItem);
        return playerItem;
    }

    public long totalPurchasedQuantity() {
        Long sum = em.createQuery(
                "SELECT COALESCE(SUM(pi.quantity), 0) FROM PlayerItem pi",
                Long.class
        ).getSingleResult();
        return sum;
    }

    public List<PlayerItem> recentPurchases(int limit) {
        return em.createQuery("SELECT pi FROM PlayerItem pi ORDER BY pi.purchasedAt DESC", PlayerItem.class)
                .setMaxResults(limit)
                .getResultList();
    }
}
