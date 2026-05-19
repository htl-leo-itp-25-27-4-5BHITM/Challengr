package control;

import entity.FriendRequest;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.util.List;

@ApplicationScoped
public class FriendRequestRepository {

    @Inject
    EntityManager em;

    @Transactional
    public FriendRequest create(String fromPlayerId, String toPlayerId) {
        if (fromPlayerId == null || fromPlayerId.isBlank()) {
            throw new IllegalArgumentException("fromPlayerId must not be blank");
        }
        if (toPlayerId == null || toPlayerId.isBlank()) {
            throw new IllegalArgumentException("toPlayerId must not be blank");
        }
        if (fromPlayerId.equals(toPlayerId)) {
            throw new IllegalArgumentException("cannot send friend request to self");
        }

        FriendRequest existing = findByPair(fromPlayerId, toPlayerId);
        if (existing != null) {
            // If there is already a record for this pair (unique constraint), allow re-sending.
            // Otherwise a previously ACCEPTED/DECLINED request would block new requests forever.
            if (existing.getStatus() != FriendRequest.Status.PENDING) {
                existing.setStatus(FriendRequest.Status.PENDING);
                existing.setCreatedAt(java.time.Instant.now());
            }
            return existing;
        }

        FriendRequest request = new FriendRequest();
        request.setFromPlayerId(fromPlayerId.trim());
        request.setToPlayerId(toPlayerId.trim());
        request.setStatus(FriendRequest.Status.PENDING);
        em.persist(request);
        return request;
    }

    public FriendRequest findByPair(String fromPlayerId, String toPlayerId) {
        return em.createQuery(
                        "SELECT r FROM FriendRequest r WHERE r.fromPlayerId = :from AND r.toPlayerId = :to",
                        FriendRequest.class
                )
                .setParameter("from", fromPlayerId)
                .setParameter("to", toPlayerId)
                .setMaxResults(1)
                .getResultStream()
                .findFirst()
                .orElse(null);
    }

    public List<FriendRequest> findOutgoing(String playerId) {
        return em.createQuery(
                        "SELECT r FROM FriendRequest r WHERE r.fromPlayerId = :pid AND r.status = :status ORDER BY r.createdAt DESC",
                        FriendRequest.class
                )
                .setParameter("pid", playerId)
                .setParameter("status", FriendRequest.Status.PENDING)
                .getResultList();
    }

    public List<FriendRequest> findIncoming(String playerId) {
        return em.createQuery(
                        "SELECT r FROM FriendRequest r WHERE r.toPlayerId = :pid AND r.status = :status ORDER BY r.createdAt DESC",
                        FriendRequest.class
                )
                .setParameter("pid", playerId)
                .setParameter("status", FriendRequest.Status.PENDING)
                .getResultList();
    }

    @Transactional
    public FriendRequest updateStatus(Long requestId, FriendRequest.Status status) {
        if (requestId == null) {
            throw new IllegalArgumentException("requestId must not be null");
        }
        if (status == null) {
            throw new IllegalArgumentException("status must not be null");
        }

        FriendRequest req = em.find(FriendRequest.class, requestId);
        if (req == null) {
            return null;
        }
        req.setStatus(status);
        return req;
    }
}
