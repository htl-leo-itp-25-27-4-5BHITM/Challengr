package boundary;

import entity.Battle;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Räumt hängende Battles auf und informiert beide Spieler:
 * - nicht beantwortete Anfragen nach BattleService.REQUEST_TIMEOUT → EXPIRED
 * - angenommene Battles ohne Fortschritt nach BattleService.ACTIVE_BATTLE_TIMEOUT → ABANDONED
 */
@ApplicationScoped
public class BattleRequestExpiryJob {

    @Inject
    BattleService battleService;

    @Scheduled(every = "10s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void expireStaleRequests() {
        List<Battle> expired = battleService.expireStaleRequests(LocalDateTime.now());
        for (Battle battle : expired) {
            String payload = """
            {
              "type": "battle-updated",
              "battleId": %d,
              "status": "EXPIRED"
            }
            """.formatted(battle.getId());

            System.out.println("Battle-Anfrage abgelaufen: " + battle.getId());
            GameSocket.sendToPlayerStatic(battle.getFromPlayer().getId(), payload);
            GameSocket.sendToPlayerStatic(battle.getToPlayer().getId(), payload);
        }
    }

    @Scheduled(every = "60s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void abandonStaleBattles() {
        List<Battle> abandoned = battleService.abandonStaleBattles(LocalDateTime.now());
        for (Battle battle : abandoned) {
            GameSocket.clearBattleStateStatic(battle.getId());

            String payload = """
            {
              "type": "battle-updated",
              "battleId": %d,
              "status": "ABANDONED"
            }
            """.formatted(battle.getId());

            System.out.println("Battle ohne Fortschritt abgebrochen: " + battle.getId());
            GameSocket.sendToPlayerStatic(battle.getFromPlayer().getId(), payload);
            GameSocket.sendToPlayerStatic(battle.getToPlayer().getId(), payload);
        }
    }
}
