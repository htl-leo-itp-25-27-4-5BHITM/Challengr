package control;

import entity.Battle;
import entity.Player;
import entity.PlayerItem;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

@ApplicationScoped
public class AdminOverviewService {

    @Inject
    PlayerRepository playerRepository;

    @Inject
    BattleRepository battleRepository;

    @Inject
    ChallengeRepository challengeRepository;

    @Inject
    ShopRepository shopRepository;

    public record PlayersKpi(long total, long active) {}

    public record TopPlayer(String name, int points) {}

    public record AdminOverview(
            PlayersKpi players,
            long activeBans,
            long totalBattles,
            long battlesToday,
            long totalChallenges,
            long totalShopPurchases,
            String mostPlayedCategory,
            TopPlayer topPlayer
    ) {}

    public record ActivityItem(String type, String detail, Instant at) {}

    /**
     * For now we compute "active players" as total players.
     * Once you track lastSeen/online state, replace this with a real online query.
     */
    public AdminOverview getOverview() {
        long totalPlayers = playerRepository.countPlayers();
        long activePlayers = totalPlayers;
        long activeBans = playerRepository.countActiveBans(Instant.now());

        long totalBattles = battleRepository.countDone();
        long battlesToday = battleRepository.countDoneSince(LocalDate.now().atStartOfDay());
        long totalChallenges = challengeRepository.count();
        long totalShopPurchases = shopRepository.totalPurchasedQuantity();
        String mostPlayedCategory = battleRepository.mostPlayedCategoryName();

        List<Player> top = playerRepository.topPlayers(1);
        TopPlayer topPlayer = top.isEmpty() ? null : new TopPlayer(top.get(0).getName(), top.get(0).getPoints());

        return new AdminOverview(
                new PlayersKpi(totalPlayers, activePlayers),
                activeBans,
                totalBattles,
                battlesToday,
                totalChallenges,
                totalShopPurchases,
                mostPlayedCategory,
                topPlayer
        );
    }

    /** Merges recent battles and shop purchases into one chronological feed. */
    public List<ActivityItem> getRecentActivity(int limit) {
        List<ActivityItem> items = new ArrayList<>();

        for (Battle b : battleRepository.findRecentDone(limit)) {
            String winnerName = b.getWinner() != null ? b.getWinner().getName() : "Unentschieden";
            String category = b.getCategory() != null ? b.getCategory().getName() : "";
            items.add(new ActivityItem(
                    "BATTLE",
                    winnerName + " gewinnt eine " + category + "-Challenge",
                    b.getCreatedAt().atZone(ZoneId.systemDefault()).toInstant()
            ));
        }

        for (PlayerItem pi : shopRepository.recentPurchases(limit)) {
            Player buyer = playerRepository.findById(pi.getPlayerId());
            String buyerName = buyer != null ? buyer.getName() : pi.getPlayerId();
            items.add(new ActivityItem(
                    "SHOP",
                    buyerName + " kauft " + pi.getItem().getName(),
                    pi.getPurchasedAt()
            ));
        }

        items.sort((a, b) -> b.at().compareTo(a.at()));
        return items.size() > limit ? items.subList(0, limit) : items;
    }
}
