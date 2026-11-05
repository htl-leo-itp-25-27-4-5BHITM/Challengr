package boundary;

import control.AccountDeletionService;
import control.BlockRepository;
import control.FriendshipRepository;
import control.RankRepository;
import entity.Player;
import entity.Rank;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import security.CurrentPlayer;

import java.time.Instant;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Ranglisten für die App: Top 10 aller Spieler, Freunde (inkl. einem selbst) und der eigene Platz.
 * Nur Name, Figur und Trophäen – nie ein Standort. Gesperrte, gelöschte und blockierte Spieler fehlen.
 * Rechnet im Speicher (wie die Dashboard-Statistik) – bei ein paar hundert Spielern völlig ausreichend.
 */
@Path("/api/leaderboard")
@Produces(MediaType.APPLICATION_JSON)
@Authenticated
public class LeaderboardResource {

    static final int TOP = 10;

    public record Row(int place, String playerId, String name, int trophies, String rankName, String character, boolean me) {}

    /** {@code me} ist null, wenn es das eigene Konto (noch) nicht gibt. */
    public record Leaderboard(List<Row> school, List<Row> friends, Row me, int totalPlayers) {}

    @Inject
    EntityManager em;

    @Inject
    CurrentPlayer current;

    @Inject
    FriendshipRepository friendships;

    @Inject
    BlockRepository blocks;

    @Inject
    RankRepository rankRepository;

    @GET
    @Transactional
    public Leaderboard get() {
        String myId = current.id();
        Instant now = Instant.now();
        Set<String> blocked = blocks.blockedWith(myId);
        List<Rank> ranks = rankRepository.getAllRanks().stream().sorted(Comparator.comparingInt(Rank::getMin)).toList();

        // Reihenfolge: Trophäen, bei Gleichstand wer höher war, dann Name – so springt die Liste nicht hin und her
        List<Player> ranked = em.createQuery("SELECT p FROM Player p", Player.class).getResultList().stream()
                .filter(p -> !AccountDeletionService.DELETED_PLAYER_ID.equals(p.getId()))
                .filter(p -> p.getBanUntil() == null || !p.getBanUntil().isAfter(now))
                .sorted(Comparator.comparingInt(Player::getTrophies).reversed()
                        .thenComparing(Comparator.comparingInt(Player::getHighestTrophies).reversed())
                        .thenComparing(p -> p.getName() == null ? "" : p.getName().toLowerCase()))
                .toList();

        // Platz wie bei Sportergebnissen: gleich viele Trophäen = gleicher Platz.
        // Blockierte zählen mit (der Platz bleibt ehrlich), werden aber nicht gezeigt.
        int[] places = new int[ranked.size()];
        for (int i = 0; i < ranked.size(); i++) {
            places[i] = i > 0 && ranked.get(i).getTrophies() == ranked.get(i - 1).getTrophies() ? places[i - 1] : i + 1;
        }

        Set<String> friendIds = new HashSet<>(friendships.listFriendIds(myId));
        List<Row> school = new java.util.ArrayList<>();
        List<Row> friends = new java.util.ArrayList<>();
        Row me = null;
        for (int i = 0; i < ranked.size(); i++) {
            Player p = ranked.get(i);
            boolean isMe = p.getId().equals(myId);
            if (!isMe && blocked.contains(p.getId())) continue;
            Rank rank = rankRepository.rankForPoints(p.getTrophies(), ranks);
            Row row = new Row(places[i], p.getId(), p.getName(), p.getTrophies(),
                    rank == null ? "Unranked" : rank.getName(), p.getCharacter(), isMe);
            if (school.size() < TOP) school.add(row);
            if (isMe) me = row;
            if (isMe || friendIds.contains(p.getId())) friends.add(row);
        }
        return new Leaderboard(school, friends, me, ranked.size());
    }
}
