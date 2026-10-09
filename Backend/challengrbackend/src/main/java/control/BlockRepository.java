package control;

import entity.PlayerBlock;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** B2: Blockierungen – gelten immer in beide Richtungen. */
@ApplicationScoped
public class BlockRepository {

    @Inject
    EntityManager em;

    /** Hat einer der beiden den anderen blockiert? */
    @Transactional
    public boolean blockedEitherWay(String a, String b) {
        if (a == null || b == null) return false;
        return em.createQuery("""
                        SELECT COUNT(x) FROM PlayerBlock x
                        WHERE (x.blockerId = :a AND x.blockedId = :b) OR (x.blockerId = :b AND x.blockedId = :a)
                        """, Long.class)
                .setParameter("a", a).setParameter("b", b).getSingleResult() > 0;
    }

    /** Alle Spieler, die mit {@code playerId} nichts mehr zu tun haben dürfen. */
    @Transactional
    public Set<String> blockedWith(String playerId) {
        Set<String> ids = new HashSet<>(em.createQuery(
                "SELECT x.blockedId FROM PlayerBlock x WHERE x.blockerId = :id", String.class)
                .setParameter("id", playerId).getResultList());
        ids.addAll(em.createQuery("SELECT x.blockerId FROM PlayerBlock x WHERE x.blockedId = :id", String.class)
                .setParameter("id", playerId).getResultList());
        return ids;
    }

    public List<String> blockedBy(String blockerId) {
        return em.createQuery("SELECT x.blockedId FROM PlayerBlock x WHERE x.blockerId = :id ORDER BY x.createdAt DESC", String.class)
                .setParameter("id", blockerId).getResultList();
    }

    /** Blockieren: entfernt auch Freundschaft, offene Anfragen und Geschenke zwischen beiden. */
    @Transactional
    public void block(String blockerId, String blockedId) {
        if (!em.createQuery("SELECT COUNT(x) FROM PlayerBlock x WHERE x.blockerId = :a AND x.blockedId = :b", Long.class)
                .setParameter("a", blockerId).setParameter("b", blockedId).getSingleResult().equals(0L)) {
            return;
        }
        em.persist(new PlayerBlock(blockerId, blockedId));
        em.createQuery("""
                        DELETE FROM Friendship f
                        WHERE (f.playerAId = :a AND f.playerBId = :b) OR (f.playerAId = :b AND f.playerBId = :a)
                        """).setParameter("a", blockerId).setParameter("b", blockedId).executeUpdate();
        em.createQuery("""
                        DELETE FROM FriendRequest r
                        WHERE (r.fromPlayerId = :a AND r.toPlayerId = :b) OR (r.fromPlayerId = :b AND r.toPlayerId = :a)
                        """).setParameter("a", blockerId).setParameter("b", blockedId).executeUpdate();
        em.createQuery("""
                        DELETE FROM FriendGift g
                        WHERE (g.fromPlayerId = :a AND g.toPlayerId = :b) OR (g.fromPlayerId = :b AND g.toPlayerId = :a)
                        """).setParameter("a", blockerId).setParameter("b", blockedId).executeUpdate();
    }

    @Transactional
    public void unblock(String blockerId, String blockedId) {
        em.createQuery("DELETE FROM PlayerBlock x WHERE x.blockerId = :a AND x.blockedId = :b")
                .setParameter("a", blockerId).setParameter("b", blockedId).executeUpdate();
    }

    /** Beim Konto-Löschen: alle Blockierungen mit diesem Spieler. */
    @Transactional
    public void deleteAllFor(String playerId) {
        em.createQuery("DELETE FROM PlayerBlock x WHERE x.blockerId = :id OR x.blockedId = :id")
                .setParameter("id", playerId).executeUpdate();
    }
}
