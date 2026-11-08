package boundary;

import control.AccountDeletionService;
import control.BlockRepository;
import control.PlayerRepository;
import entity.Battle;
import entity.Player;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import security.CurrentPlayer;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/**
 * Erzfeind: der Spieler, gegen den man am öftesten gespielt hat (mindestens {@link #MIN_BATTLES} Battles),
 * mit Bilanz. Bei Gleichstand der, gegen den man zuletzt gespielt hat. Ohne Erzfeind: 204.
 */
@Path("/api/nemesis")
@Produces(MediaType.APPLICATION_JSON)
@Authenticated
public class NemesisResource {

    static final int MIN_BATTLES = 3;

    public record Nemesis(String playerId, String name, String character, int battles, int wins, int losses) {}

    @Inject
    CurrentPlayer current;

    @Inject
    PlayerRepository players;

    @Inject
    BlockRepository blocks;

    @GET
    @Transactional
    public Response get() {
        Player me = players.findById(current.id());
        if (me == null) return Response.noContent().build();
        Nemesis n = find(me, blocks.blockedWith(me.getId()));
        return n == null ? Response.noContent().build() : Response.ok(n).build();
    }

    Nemesis find(Player me, Set<String> blocked) {
        record Tally(Player opponent, int battles, int wins, int losses, long lastId) {}
        Map<String, Tally> byOpponent = new HashMap<>();
        for (Battle b : players.findDoneBattlesForPlayer(me)) {
            Player other = b.getFromPlayer().getId().equals(me.getId()) ? b.getToPlayer() : b.getFromPlayer();
            if (AccountDeletionService.DELETED_PLAYER_ID.equals(other.getId()) || blocked.contains(other.getId())) continue;
            boolean won = b.getWinner() != null && b.getWinner().getId().equals(me.getId());
            boolean lost = b.getWinner() != null && b.getWinner().getId().equals(other.getId());
            byOpponent.merge(other.getId(), new Tally(other, 1, won ? 1 : 0, lost ? 1 : 0, b.getId()),
                    (a, c) -> new Tally(a.opponent(), a.battles() + 1, a.wins() + c.wins(), a.losses() + c.losses(),
                            Math.max(a.lastId(), c.lastId())));
        }
        return byOpponent.values().stream()
                .filter(t -> t.battles() >= MIN_BATTLES)
                .max((a, c) -> a.battles() != c.battles() ? Integer.compare(a.battles(), c.battles())
                        : Long.compare(a.lastId(), c.lastId()))
                .map(t -> new Nemesis(t.opponent().getId(), t.opponent().getName(), t.opponent().getCharacter(),
                        t.battles(), t.wins(), t.losses()))
                .orElse(null);
    }
}
