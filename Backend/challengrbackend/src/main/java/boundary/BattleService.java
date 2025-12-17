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

    // Winner setzen und Battle abschließen
    @Transactional
    public Battle finishBattle(Long battleId, Long winnerPlayerId) {
        Battle battle = battleRepository.findById(battleId);
        if (battle == null) {
            throw new IllegalArgumentException("battle not found");
        }

        Player winner = playerRepository.findById(winnerPlayerId);
        if (winner == null) {
            throw new IllegalArgumentException("winner not found");
        }

        battle.setWinner(winner);   // vorausgesetzt: Feld winner in Battle-Entity
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
