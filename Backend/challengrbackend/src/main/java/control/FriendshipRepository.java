package control;

import entity.Friendship;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.util.ArrayList;
import java.util.List;

@ApplicationScoped
public class FriendshipRepository {

    @Inject
    EntityManager em;

    private static String a(String p1, String p2) {
        return p1.compareTo(p2) <= 0 ? p1 : p2;
    }

    private static String b(String p1, String p2) {
        return p1.compareTo(p2) <= 0 ? p2 : p1;
    }

    @Transactional
    public Friendship createIfMissing(String player1, String player2) {
        if (player1 == null || player1.isBlank() || player2 == null || player2.isBlank()) {
            throw new IllegalArgumentException("player ids must not be blank");
        }
        if (player1.equals(player2)) {
            throw new IllegalArgumentException("cannot friend self");
        }

        String pa = a(player1.trim(), player2.trim());
        String pb = b(player1.trim(), player2.trim());

        Friendship existing = findByPair(pa, pb);
        if (existing != null) {
            return existing;
        }

        Friendship f = new Friendship();
        f.setPlayerAId(pa);
        f.setPlayerBId(pb);
        em.persist(f);
        return f;
    }

    public Friendship findByPair(String playerA, String playerB) {
        return em.createQuery(
                        "SELECT f FROM Friendship f WHERE f.playerAId = :a AND f.playerBId = :b",
                        Friendship.class
                )
                .setParameter("a", playerA)
                .setParameter("b", playerB)
                .setMaxResults(1)
                .getResultStream()
                .findFirst()
                .orElse(null);
    }

    public List<String> listFriendIds(String playerId) {
        List<String> out = new ArrayList<>();

        // playerId on side A
        out.addAll(
                em.createQuery(
                                "SELECT f.playerBId FROM Friendship f WHERE f.playerAId = :pid",
                                String.class
                        )
                        .setParameter("pid", playerId)
                        .getResultList()
        );

        // playerId on side B
        out.addAll(
                em.createQuery(
                                "SELECT f.playerAId FROM Friendship f WHERE f.playerBId = :pid",
                                String.class
                        )
                        .setParameter("pid", playerId)
                        .getResultList()
        );

        return out;
    }

    @Transactional
    public boolean remove(String player1, String player2) {
        String pa = a(player1.trim(), player2.trim());
        String pb = b(player1.trim(), player2.trim());

        Friendship existing = findByPair(pa, pb);
        if (existing == null) {
            return false;
        }
        em.remove(existing);
        return true;
    }
}
