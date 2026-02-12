package boundary;

import control.*;
import entity.*;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

import java.util.Comparator;
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

    @Inject
    RankRepository rankRepository;

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
    public void finalizeResult(Long battleId, String winnerName) {

        Battle battle = battleRepository.findById(battleId);
        if (battle == null) throw new IllegalArgumentException("battle not found");

        Player from = battle.getFromPlayer();
        Player to   = battle.getToPlayer();

        Player winner;
        Player loser;

        if (winnerName != null && winnerName.equalsIgnoreCase(from.getName())) {
            winner = from;
            loser  = to;
        } else if (winnerName != null && winnerName.equalsIgnoreCase(to.getName())) {
            winner = to;
            loser  = from;
        } else {
            throw new IllegalArgumentException("winnerName does not match battle players");
        }

        // alle Ranks laden und nach min sortieren
        List<Rank> ranks = rankRepository.getAllRanks()
                .stream()
                .sorted(Comparator.comparingInt(Rank::getMin))
                .toList();

        Rank winnerRank = rankRepository.rankForPoints(winner.getPoints(), ranks);
        Rank loserRank  = rankRepository.rankForPoints(loser.getPoints(), ranks);

        int rankDiff = 0;
        int absDiff  = 0;
        if (winnerRank != null && loserRank != null) {
            int winnerIndex = ranks.indexOf(winnerRank);
            int loserIndex  = ranks.indexOf(loserRank);
            rankDiff = winnerIndex - loserIndex;   // 0 = gleich, <0 = Gewinner war tiefer, >0 = höher
            absDiff  = Math.abs(rankDiff);
        }

        int baseWin  = 30;    // Standard +30
        int baseLoss = -20;   // Standard -20
        double factor = 0.05; // 5 % pro Rangunterschied

        int winnerDelta;
        int loserDelta;

        if (rankDiff == 0) {
            // gleicher Rank
            winnerDelta = baseWin;
            loserDelta  = baseLoss;

        } else if (rankDiff < 0) {
            // Gewinner war UNTERLEGEN (tieferer Rank)
            double bonusWin  = baseWin  * factor * absDiff;
            double bonusLoss = baseLoss * factor * absDiff; // baseLoss ist negativ → stärker ins Minus

            winnerDelta = (int) Math.round(baseWin  + bonusWin);
            loserDelta  = (int) Math.round(baseLoss + bonusLoss);

        } else {
            // Gewinner war FAVORIT (höherer Rank)
            double penaltyWin  = baseWin  * factor * absDiff;
            double penaltyLoss = baseLoss * factor * absDiff; // baseLoss ist negativ → Verlust wird kleiner (Richtung 0)

            winnerDelta = (int) Math.round(baseWin  - penaltyWin);
            loserDelta  = (int) Math.round(baseLoss - penaltyLoss);
        }

        winner.setPoints(winner.getPoints() + winnerDelta);
        loser.setPoints(loser.getPoints() + loserDelta);

        battle.setWinner(winner);
        battle.setStatus("DONE");
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
