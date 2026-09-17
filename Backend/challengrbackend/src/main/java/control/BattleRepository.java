package control;

import entity.Battle;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

import java.time.LocalDateTime;
import java.util.List;

@ApplicationScoped
public class BattleRepository implements PanacheRepository<Battle> {

    // All battles where given player is the target
    public List<Battle> findIncoming(String toPlayerId) {
        return find("toPlayer.id = ?1 ORDER BY createdAt DESC", toPlayerId).list();
    }

    // Open battles (REQUESTED) for a player
    public List<Battle> findOpen(String toPlayerId) {
        return find("toPlayer.id = ?1 AND status = ?2", toPlayerId, "REQUESTED").list();
    }

    // All battles between two players (optional helper)
    public List<Battle> findBetween(String fromId, String toId) {
        return find("fromPlayer.id = ?1 AND toPlayer.id = ?2", fromId, toId).list();
    }

    public long countDone() {
        return count("status = ?1", "DONE");
    }

    public long countDoneSince(LocalDateTime since) {
        return count("status = ?1 AND createdAt >= ?2", "DONE", since);
    }

    public List<Battle> findRecentDone(int limit) {
        return find("status = ?1 ORDER BY createdAt DESC", "DONE").page(0, limit).list();
    }

    /** Category name with the most DONE battles, or null if there are none yet. */
    public String mostPlayedCategoryName() {
        List<Object[]> rows = getEntityManager().createQuery(
                "SELECT b.category.name, COUNT(b) FROM Battle b WHERE b.status = 'DONE' " +
                        "GROUP BY b.category.name ORDER BY COUNT(b) DESC",
                Object[].class
        ).setMaxResults(1).getResultList();

        return rows.isEmpty() ? null : (String) rows.get(0)[0];
    }
}
