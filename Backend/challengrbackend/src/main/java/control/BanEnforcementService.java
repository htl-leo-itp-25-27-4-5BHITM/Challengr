package control;

import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;

import java.time.Instant;

@ApplicationScoped
public class BanEnforcementService {

    public static final String PLAYER_ID_HEADER = "X-Player-Id";

    @Inject
    EntityManager em;

    /**
     * If the given playerId is currently banned, throws {@link BannedException}.
     * If playerId is null/blank or player doesn't exist, it's a no-op.
     */
    public void assertNotBanned(String playerId) {
        if (playerId == null || playerId.isBlank()) {
            return;
        }
        Player p = em.find(Player.class, playerId);
        if (p == null || p.getBanUntil() == null) {
            return;
        }
        if (p.getBanUntil().isAfter(Instant.now())) {
            throw new BannedException(p.getBanUntil(), p.getBanReason());
        }
    }
}
