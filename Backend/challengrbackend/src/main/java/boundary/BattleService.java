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

    // Winner setzen, Punkte vergeben und Battle abschließen
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

        // Gewinner/Verlierer bestimmen
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

        // Punkte anpassen (hier: +20 / -10, kannst du frei wählen)
        winner.setPoints(winner.getPoints() + 20);
        loser.setPoints(loser.getPoints() - 10);

        // Winner im Battle speichern und Status setzen
        battle.setWinner(winner);
        battle.setStatus("DONE");

        // Durch @Transactional werden Änderungen an Battle + Playern gespeichert
        return battle;
    }

    public List<Battle> getIncomingBattles(Long playerId) {
        return battleRepository.findIncoming(playerId);
    }

    public List<Battle> getOpenBattles(Long playerId) {
        return battleRepository.findOpen(playerId);
    }
}
