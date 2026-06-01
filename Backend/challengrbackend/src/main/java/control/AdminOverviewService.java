package control;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.time.Instant;

@ApplicationScoped
public class AdminOverviewService {

    @Inject
    PlayerRepository playerRepository;

    public record PlayersKpi(long total, long active) {}

    public record AdminOverview(PlayersKpi players, long activeBans) {}

    /**
     * For now we compute “active players” as total players.
     * Once you track lastSeen/online state, replace this with a real online query.
     */
    public AdminOverview getOverview() {
        long totalPlayers = playerRepository.countPlayers();
        long activePlayers = totalPlayers;

        long activeBans = playerRepository.countActiveBans(Instant.now());

        return new AdminOverview(new PlayersKpi(totalPlayers, activePlayers), activeBans);
    }
}
