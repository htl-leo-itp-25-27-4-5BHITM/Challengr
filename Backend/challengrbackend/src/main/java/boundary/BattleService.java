package boundary;

import control.BattleRepository;
import control.ChallengeCategoriesRepository;
import control.ChallengeRepository;
import control.PlayerRepository;
import entity.Battle;
import entity.ChallengeCategory;
import entity.Challenges;
import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

import java.util.List;

@ApplicationScoped
public class BattleService {

    @Inject
    BattleRepository battleRepository;

    @Inject
    PlayerRepository playerRepository;

    @Inject
    ChallengeRepository challengeRepository;

    @Inject
    ChallengeCategoriesRepository categoryRepository;

    public Battle findById(Long battleId) {
        return battleRepository.findById(battleId);
    }

    // Neues Battle anlegen
    @Transactional
    public Battle createRequestedBattle(Long fromPlayerId,
                                        Long toPlayerId,
                                        Long challengeId) {

        Player from = playerRepository.findById(fromPlayerId);
        if (from == null) {
            throw new IllegalArgumentException("fromPlayer not found");
        }

        Player to = playerRepository.findById(toPlayerId);
        if (to == null) {
            throw new IllegalArgumentException("toPlayer not found");
        }

        Challenges challenge = challengeRepository.findById(challengeId);
        if (challenge == null) {
            throw new IllegalArgumentException("challenge not found");
        }

        ChallengeCategory category = challenge.getChallengeCategory();

        Battle battle = new Battle();
        battle.setFromPlayer(from);
        battle.setToPlayer(to);
        battle.setChallenge(challenge);
        battle.setCategory(category);
        battle.setStatus("REQUESTED");
        battle.setType("NORMAL");

        battleRepository.persist(battle);
        return battle;
    }

    // Status ändern
    @Transactional
    public Battle updateStatus(Long battleId, String newStatus) {
        Battle battle = battleRepository.findById(battleId);
        if (battle == null) {
            throw new IllegalArgumentException("battle not found");
        }
        battle.setStatus(newStatus);
        return battle;
    }

    // NEU: Wird vom GameSocket mit winnerName aufgerufen
    @Transactional
    public void finalizeResult(Long battleId, String winnerName,
                               int winnerDelta, int loserDelta) {

        Battle battle = battleRepository.findById(battleId);
        if (battle == null) {
            throw new IllegalArgumentException("battle not found");
        }

        Player from = battle.getFromPlayer();
        Player to   = battle.getToPlayer();
        if (from == null || to == null) {
            throw new IllegalStateException("battle players not set");
        }

        Long winnerPlayerId;
        Player winner;
        Player loser;

        if (winnerName != null && winnerName.equalsIgnoreCase(from.getName())) {
            winnerPlayerId = from.getId();
            winner = from;
            loser  = to;
        } else if (winnerName != null && winnerName.equalsIgnoreCase(to.getName())) {
            winnerPlayerId = to.getId();
            winner = to;
            loser  = from;
        } else {
            throw new IllegalArgumentException("winnerName does not match battle players");
        }

        // Punkte anpassen
        winner.setPoints(winner.getPoints() + winnerDelta);
        loser.setPoints(loser.getPoints() + loserDelta);

        // Winner im Battle speichern und Status setzen
        battle.setWinner(winner);
        battle.setStatus("DONE");

        System.out.println("finalizeResult: battleId=" + battleId +
                " winner=" + winner.getName() +
                " (" + winnerPlayerId + "), points: " +
                winner.getPoints() + "/" + loser.getPoints());
    }

    // Winner setzen, Punkte vergeben und Battle abschließen (per ID)
    @Transactional
    public Battle finishBattle(Long battleId, Long winnerPlayerId) {
        System.out.println("finishBattle called: battleId=" + battleId +
                ", winnerPlayerId=" + winnerPlayerId);

        Battle battle = battleRepository.findById(battleId);
        if (battle == null) {
            throw new IllegalArgumentException("battle not found");
        }

        Player winner = playerRepository.findById(winnerPlayerId);
        if (winner == null) {
            throw new IllegalArgumentException("winner not found");
        }

        Player from = battle.getFromPlayer();
        Player to   = battle.getToPlayer();

        Player loser;
        if (from.getId().equals(winnerPlayerId)) {
            loser = to;
        } else if (to.getId().equals(winnerPlayerId)) {
            loser = from;
        } else {
            throw new IllegalArgumentException("winner is not part of this battle");
        }

        winner.setPoints(winner.getPoints() + 20);
        loser.setPoints(loser.getPoints() - 10);

        battle.setWinner(winner);
        battle.setStatus("DONE");

        return battle;
    }

    public List<Battle> getIncomingBattles(Long playerId) {
        return battleRepository.findIncoming(playerId);
    }

    public List<Battle> getOpenBattles(Long playerId) {
        return battleRepository.findOpen(playerId);
    }
}
