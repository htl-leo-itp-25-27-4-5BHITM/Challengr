package control;

import entity.FriendGift;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.time.Instant;
import java.util.List;

@ApplicationScoped
public class FriendGiftRepository {

    @Inject
    EntityManager em;

    @Inject
    StickerRepository stickers;

    /** Hat from seit `since` schon ein Zufalls-Geschenk an to geschickt? (eins pro Freund und Tag) */
    public boolean sentSince(String fromPlayerId, String toPlayerId, Instant since) {
        return em.createQuery(
                        "SELECT COUNT(g) FROM FriendGift g WHERE g.fromPlayerId = :f AND g.toPlayerId = :t AND g.createdAt >= :since"
                                + " AND g.fromCollection = false",
                        Long.class)
                .setParameter("f", fromPlayerId)
                .setParameter("t", toPlayerId)
                .setParameter("since", since)
                .getSingleResult() > 0;
    }

    @Transactional
    public FriendGift create(String fromPlayerId, String toPlayerId) {
        return create(fromPlayerId, toPlayerId, null);
    }

    /** stickerId != null: der Absender verschenkt einen eigenen Sticker (wird gleich abgezogen). */
    @Transactional
    public FriendGift create(String fromPlayerId, String toPlayerId, String stickerId) {
        if (fromPlayerId == null || fromPlayerId.isBlank() || toPlayerId == null || toPlayerId.isBlank()) {
            throw new IllegalArgumentException("player ids must not be blank");
        }
        if (fromPlayerId.trim().equals(toPlayerId.trim())) {
            throw new IllegalArgumentException("cannot send gift to self");
        }

        FriendGift gift = new FriendGift();
        gift.setFromPlayerId(fromPlayerId.trim());
        gift.setToPlayerId(toPlayerId.trim());
        gift.setStatus(FriendGift.Status.PENDING);
        if (stickerId != null) {
            if (stickers.consume(gift.getFromPlayerId(), stickerId) < 0) {
                throw new IllegalStateException("Diesen Sticker hast du gerade nicht");
            }
            gift.setStickerId(stickerId);
            gift.setFromCollection(true);
        }
        em.persist(gift);
        return gift;
    }

    public List<FriendGift> findIncomingPending(String playerId) {
        return em.createQuery(
                        "SELECT g FROM FriendGift g WHERE g.toPlayerId = :pid AND g.status = :status ORDER BY g.createdAt DESC",
                        FriendGift.class
                )
                .setParameter("pid", playerId)
                .setParameter("status", FriendGift.Status.PENDING)
                .getResultList();
    }

    @Transactional
    public FriendGift claim(Long giftId, String playerId) {
        FriendGift gift = em.find(FriendGift.class, giftId);
        if (gift == null) {
            return null;
        }
        if (!gift.getToPlayerId().equals(playerId)) {
            throw new IllegalArgumentException("gift does not belong to player");
        }
        if (gift.getStatus() == FriendGift.Status.CLAIMED) {
            return gift;
        }

        gift.setStatus(FriendGift.Status.CLAIMED);
        gift.setClaimedAt(Instant.now());
        // Drin ist der ausgesuchte oder ein zufälliger Sticker – kommt in die Sammlung
        if (gift.getStickerId() == null) gift.setStickerId(stickers.randomSticker());
        stickers.grant(playerId, gift.getStickerId());
        return gift;
    }
}