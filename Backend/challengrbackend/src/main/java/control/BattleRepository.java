package control;

import entity.Battle;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.List;

@ApplicationScoped
public class BattleRepository implements PanacheRepository<Battle> {

    // All battles where given player is the target
    public List<Battle> findIncoming(Long toPlayerId) {
        return find("toPlayer.id = ?1 ORDER BY createdAt DESC", toPlayerId).list();
    }

    // Open battles (REQUESTED) for a player
    public List<Battle> findOpen(Long toPlayerId) {
        return find("toPlayer.id = ?1 AND status = ?2", toPlayerId, "REQUESTED").list();
    }

    // All battles between two players (optional helper)
    public List<Battle> findBetween(Long fromId, Long toId) {
        return find("fromPlayer.id = ?1 AND toPlayer.id = ?2", fromId, toId).list();
    }
}
