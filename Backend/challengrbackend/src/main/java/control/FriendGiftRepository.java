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

    @Transactional
    public FriendGift create(String fromPlayerId, String toPlayerId) {
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
        return gift;
    }
}