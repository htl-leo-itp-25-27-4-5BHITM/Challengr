package boundary;

import control.*;
import entity.*;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.LockModeType;
import jakarta.transaction.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;

@ApplicationScoped
public class BattleService {

    @Inject
    BattleRepository battleRepository;

    @Inject
    control.BlockRepository blockRepository;

    @Inject
    PlayerRepository playerRepository;

    @Inject
    ChallengeRepository challengeRepository;

    @Inject
    ChallengeCategoriesRepository categoryRepository;

    @Inject
    RankRepository rankRepository;

    @Transactional
    public Battle findById(Long battleId) {
        return battleRepository.findById(battleId);
    }

    @Transactional
    public void updatePlayer(Player player) {
        playerRepository.save(player);
    }

    /** "Konflikte in Folge" zurücksetzen – lädt die Spieler frisch (kein Überschreiben mit altem Stand). */
    @Transactional
    public void resetConflicts(String... playerIds) {
        for (String id : playerIds) {
            Player p = playerRepository.findById(id);
            if (p != null) p.setConsecutiveConflicts(0);
        }
    }

    /**
     * Konflikt (beide stimmen für sich selbst) zählen. Ab dem 3. in Folge gibt es Abzug:
     * 3 → 10, 4 → 20 … Punkte. Lädt den Spieler frisch.
     * @return Abzug in Punkten
     */
    @Transactional
    public int applyConflict(String playerId) {
        Player player = playerRepository.findById(playerId);
        if (player == null) return 0;
        int current = player.getConsecutiveConflicts() + 1;
        player.setConsecutiveConflicts(current);
        int penalty = current >= 3 ? (current - 2) * 10 : 0;
        if (penalty > 0) {
            player.setPoints(player.getPoints() - penalty);
        }
        System.out.printf("Konflikt für %s: %d in Folge, Abzug %d%n", player.getName(), current, penalty);
        return penalty;
    }

    // Neues Battle anlegen (ohne Modus = Friendly, z.B. alte Apps)
    @Transactional
    public Battle createRequestedBattle(String fromPlayerId,
                                        String toPlayerId,
                                        Long challengeId) {
        return createRequestedBattle(fromPlayerId, toPlayerId, challengeId, BattleMode.FRIENDLY);
    }

    /**
     * Neues Battle anlegen.
     * Liga: der Server wählt die Challenge zufällig (Wissen-Frage bzw. vom Handy gemessene Challenge),
     * damit sich niemand seine Lieblings-Challenge aussucht. Friendly: challengeId vom Herausforderer.
     */
    @Transactional
    public Battle createRequestedBattle(String fromPlayerId,
                                        String toPlayerId,
                                        Long challengeId,
                                        BattleMode mode) {

        if (fromPlayerId == null || toPlayerId == null) {
            throw new BattleRejectedException("Spieler fehlt");
        }
        if (fromPlayerId.equals(toPlayerId)) {
            throw new BattleRejectedException("Du kannst dich nicht selbst herausfordern");
        }
        // B2: blockiert (egal von wem) → keine Herausforderung möglich
        if (blockRepository.blockedEitherWay(fromPlayerId, toPlayerId)) {
            throw new BattleRejectedException("Dieser Spieler ist nicht erreichbar");
        }
        if (battleRepository.existsOpenRequestBetween(fromPlayerId, toPlayerId,
                LocalDateTime.now().minus(REQUEST_TIMEOUT))) {
            throw new BattleRejectedException("Mit diesem Spieler läuft schon eine offene Challenge");
        }
        // Wer mitten im Battle steckt, kann keine neue Anfrage bekommen oder schicken
        if (isInRunningBattle(toPlayerId)) {
            throw new BattleRejectedException("Spieler ist gerade in einem Battle");
        }
        if (isInRunningBattle(fromPlayerId)) {
            throw new BattleRejectedException("Du bist gerade in einem Battle");
        }

        Player from = playerRepository.findById(fromPlayerId);
        if (from == null) {
            throw new IllegalArgumentException("fromPlayer not found");
        }

        Player to = playerRepository.findById(toPlayerId);
        if (to == null) {
            throw new IllegalArgumentException("toPlayer not found");
        }

        Challenges challenge = pickChallenge(mode, challengeId);

        ChallengeCategory category = challenge.getChallengeCategory();

        Battle battle = new Battle();
        battle.setFromPlayer(from);
        battle.setToPlayer(to);
        battle.setChallenge(challenge);
        battle.setCategory(category);
        battle.setStatus("REQUESTED");
        battle.setType(mode.name());

        // ⬇️ Zielpunkt für iPhone-Check-In-Spot-Challenge setzen
        if ("iPhone".equalsIgnoreCase(category.getName())
                && challenge.getText() != null
                && challenge.getText().contains("Check-In-Spot")) {

            Double playerLat = from.getLatitude();
            Double playerLon = from.getLongitude();

            if (playerLat != null && playerLon != null) {
                double radius = 500.0; // 500 m

                double angle = Math.random() * 2 * Math.PI;
                double r = radius * Math.sqrt(Math.random());

                double dLat = (r * Math.cos(angle)) / 111_320.0;
                double dLon = (r * Math.sin(angle)) / (111_320.0 * Math.cos(Math.toRadians(playerLat)));

                double targetLat = playerLat + dLat;
                double targetLon = playerLon + dLon;

                battle.setTargetLatitude(targetLat);
                battle.setTargetLongitude(targetLon);
            }
        }

        battleRepository.persist(battle);
        return battle;
    }

    /**
     * Status eines laufenden Battles ändern (READY_FOR_VOTING, DONE_SURRENDER, CHECKIN_DONE …).
     * Prüfen und Setzen passieren gesperrt in einem Schritt – sonst könnte ein
     * gleichzeitiger Aufruf ein schon beendetes Battle wieder "aufwecken".
     *
     * @return das Battle, oder null wenn es nicht läuft (noch Anfrage oder schon beendet)
     */
    @Transactional
    public Battle updateRunningStatus(Long battleId, String newStatus) {
        Battle battle = battleRepository.findById(battleId, LockModeType.PESSIMISTIC_WRITE);
        if (battle == null || isFinal(battle.getStatus()) || "REQUESTED".equals(battle.getStatus())) {
            return null;
        }
        battle.setStatus(newStatus);
        battle.getFromPlayer().getId();
        battle.getToPlayer().getId();
        return battle;
    }

    // Status ändern (ohne Prüfung – nur für Tests/Admin)
    @Transactional
    public Battle updateStatus(Long battleId, String newStatus) {
        Battle battle = battleRepository.findById(battleId);
        if (battle == null) {
            throw new IllegalArgumentException("battle not found");
        }
        battle.setStatus(newStatus);
        return battle;
    }

    /** Wie lange eine Anfrage angenommen werden kann, bevor sie abläuft. */
    public static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(60);

    /** Ein angenommenes Battle ohne Fortschritt wird nach dieser Zeit abgebrochen (ohne Punkte). */
    public static final Duration ACTIVE_BATTLE_TIMEOUT = Duration.ofMinutes(10);

    /** Endzustände – danach passiert mit dem Battle nichts mehr. */
    public static final List<String> FINAL_STATUSES =
            List.of("DONE", "EXPIRED", "CANCELLED", "DECLINED", "ABANDONED");

    public static boolean isFinal(String status) {
        return status != null && FINAL_STATUSES.contains(status);
    }

    /**
     * Bricht laufende Battles ab, bei denen seit ACTIVE_BATTLE_TIMEOUT nichts passiert ist
     * (z.B. ein Spieler hat die App geschlossen). Keine Punkte für niemanden.
     */
    @Transactional
    public List<Battle> abandonStaleBattles(LocalDateTime now) {
        List<String> notActive = new java.util.ArrayList<>(FINAL_STATUSES);
        notActive.add("REQUESTED"); // Anfragen laufen über REQUEST_TIMEOUT ab
        List<Battle> stale = battleRepository.findActiveStaleSince(now.minus(ACTIVE_BATTLE_TIMEOUT), notActive);
        for (Battle b : stale) {
            b.setStatus("ABANDONED");
            b.getFromPlayer().getId();
            b.getToPlayer().getId();
        }
        return stale;
    }

    /**
     * Status-Wechsel, der nur aus REQUESTED erlaubt ist (ACCEPTED, DECLINED, CANCELLED).
     * - CANCELLED darf nur der Herausforderer (from) setzen.
     * - ACCEPTED/DECLINED darf nur der Herausgeforderte (to) setzen.
     * - Abgelaufene Anfragen werden dabei auf EXPIRED gesetzt.
     * Gibt das Battle zurück, wenn der Wechsel passiert ist, sonst null.
     */
    @Transactional
    public Battle transitionFromRequested(Long battleId, String newStatus, String byPlayerId) {
        Battle battle = battleRepository.findById(battleId);
        if (battle == null || !"REQUESTED".equals(battle.getStatus())) {
            return null;
        }

        String fromId = battle.getFromPlayer().getId();
        String toId   = battle.getToPlayer().getId();
        if ("CANCELLED".equals(newStatus)) {
            if (byPlayerId != null && !byPlayerId.equals(fromId)) return null;
        } else if (byPlayerId != null && !byPlayerId.equals(toId)) {
            return null;
        }

        if (isExpired(battle, LocalDateTime.now())) {
            battle.setStatus("EXPIRED");
            return "ACCEPTED".equals(newStatus) ? null : battle;
        }

        battle.setStatus(newStatus);
        return battle;
    }

    /** Setzt alle zu alten REQUESTED-Battles auf EXPIRED und gibt sie zurück. */
    @Transactional
    public List<Battle> expireStaleRequests(LocalDateTime now) {
        List<Battle> stale = battleRepository.findRequestedOlderThan(now.minus(REQUEST_TIMEOUT));
        for (Battle b : stale) {
            b.setStatus("EXPIRED");
            // Lazy-Felder für den Aufrufer außerhalb der Transaktion laden
            b.getFromPlayer().getId();
            b.getToPlayer().getId();
        }
        return stale;
    }

    /** Offene, noch gültige Anfragen an einen Spieler (z.B. nach Reconnect erneut zustellen). */
    @Transactional
    public List<Battle> findPendingRequestsFor(String toPlayerId, LocalDateTime now) {
        List<Battle> pending = battleRepository.findRequestedForSince(toPlayerId, now.minus(REQUEST_TIMEOUT));
        for (Battle b : pending) {
            b.getChallenge().getText();
            if (b.getChallenge().getChallengeCategory() != null) {
                b.getChallenge().getChallengeCategory().getName();
            }
        }
        return pending;
    }

    /** Offene, noch gültige Anfragen, die ein Spieler selbst geschickt hat (nach Reconnect wiederherstellen). */
    @Transactional
    public List<Battle> findPendingRequestsFrom(String fromPlayerId, LocalDateTime now) {
        List<Battle> pending = battleRepository.findRequestedFromSince(fromPlayerId, now.minus(REQUEST_TIMEOUT));
        for (Battle b : pending) {
            b.getToPlayer().getId();
            b.getChallenge().getText();
            if (b.getChallenge().getChallengeCategory() != null) {
                b.getChallenge().getChallengeCategory().getName();
            }
        }
        return pending;
    }

    /** Laufende Battles eines Spielers, z.B. um sie nach einem App-Neustart wieder anzuzeigen. */
    @Transactional
    public List<Battle> findRunningBattlesFor(String playerId) {
        List<String> notRunning = new java.util.ArrayList<>(FINAL_STATUSES);
        notRunning.add("REQUESTED");
        List<Battle> running = battleRepository.findRunningFor(playerId, notRunning,
                LocalDateTime.now().minus(ACTIVE_BATTLE_TIMEOUT));
        for (Battle b : running) {
            b.getFromPlayer().getId();
            b.getToPlayer().getId();
            b.getChallenge().getText();
            if (b.getChallenge().getChallengeCategory() != null) {
                b.getChallenge().getChallengeCategory().getName();
            }
        }
        return running;
    }

    /** Angenommen und noch nicht beendet (abgelaufene Battles bricht der Timeout-Job ab). */
    @Transactional
    public boolean isInRunningBattle(String playerId) {
        List<String> notRunning = new java.util.ArrayList<>(FINAL_STATUSES);
        notRunning.add("REQUESTED");
        return battleRepository.existsRunningBattleFor(playerId, notRunning,
                LocalDateTime.now().minus(ACTIVE_BATTLE_TIMEOUT));
    }

    static boolean isExpired(Battle battle, LocalDateTime now) {
        return battle.getCreatedAt() != null
                && battle.getCreatedAt().isBefore(now.minus(REQUEST_TIMEOUT));
    }

    /**
     * Markiert ein Battle als DONE – aber nur beim ersten Aufruf.
     * Die Zeile wird dabei gesperrt, damit zwei gleichzeitige Auswertungen
     * (z.B. Aufgeben + Ergebnis) nicht beide Punkte vergeben.
     *
     * @return true, wenn dieser Aufruf das Battle beendet hat
     */
    @Transactional
    public boolean markDone(Long battleId) {
        Battle battle = battleRepository.findById(battleId, LockModeType.PESSIMISTIC_WRITE);
        if (battle == null || isFinal(battle.getStatus()) || "REQUESTED".equals(battle.getStatus())) {
            return false; // schon fertig/abgebrochen oder noch gar nicht angenommen
        }
        battle.setStatus("DONE");
        return true;
    }

    private static final java.util.Random RANDOM = new java.util.Random();

    private Challenges pickChallenge(BattleMode mode, Long challengeId) {
        if (mode == BattleMode.FRIENDLY) {
            if (challengeId == null) {
                throw new BattleRejectedException("Bitte eine Challenge wählen");
            }
            Challenges challenge = challengeRepository.findById(challengeId);
            if (challenge == null) {
                throw new IllegalArgumentException("challenge not found");
            }
            return challenge;
        }
        List<Challenges> pool = challengeRepository.findChallengesByKat(
                        mode == BattleMode.RANKED_KNOWLEDGE ? BattleMode.KNOWLEDGE_CATEGORY : BattleMode.REALLIFE_CATEGORY)
                .stream()
                .filter(c -> mode != BattleMode.RANKED_KNOWLEDGE || c.getCorrectIndex() != null)
                .toList();
        if (pool.isEmpty()) {
            throw new BattleRejectedException("Für diese Liga gibt es noch keine Challenges");
        }
        return pool.get(RANDOM.nextInt(pool.size()));
    }

    /** Zufällige Wissensfragen für die Quiz-Show (ohne Wiederholung, die erste ist die des Battles). */
    @Transactional
    public List<Challenges> quizQuestions(Long battleId, int count) {
        Battle battle = battleRepository.findById(battleId);
        List<Challenges> pool = new java.util.ArrayList<>(challengeRepository.findChallengesByKat(BattleMode.KNOWLEDGE_CATEGORY)
                .stream().filter(c -> c.getCorrectIndex() != null).toList());
        java.util.Collections.shuffle(pool, RANDOM);
        List<Challenges> result = new java.util.ArrayList<>();
        if (battle != null && battle.getChallenge() != null && battle.getChallenge().getCorrectIndex() != null) {
            result.add(battle.getChallenge());
        }
        for (Challenges c : pool) {
            if (result.size() >= count) break;
            if (result.stream().noneMatch(r -> r.getId() == c.getId())) result.add(c);
        }
        result.forEach(c -> { c.getText(); c.getOptionA(); c.getOptionB(); c.getOptionC(); c.getOptionD(); });
        return result;
    }

    /**
     * Ergebnis verbuchen – Gewinner über die Spieler-ID (Namen können doppelt vorkommen).
     * Friendly: es geht um nichts. Liga: Trophäen der Liga (+/-), der Sieger bekommt seinen
     * Trophäen-Gewinn zusätzlich als Punkte (Währung für den Shop).
     */
    @Transactional
    public void finalizeResult(Long battleId, String winnerPlayerId) {

        Battle battle = battleRepository.findById(battleId);
        if (battle == null) throw new IllegalArgumentException("battle not found");

        Player from = battle.getFromPlayer();
        Player to   = battle.getToPlayer();

        Player winner;
        Player loser;

        if (winnerPlayerId != null && winnerPlayerId.equals(from.getId())) {
            winner = from;
            loser  = to;
        } else if (winnerPlayerId != null && winnerPlayerId.equals(to.getId())) {
            winner = to;
            loser  = from;
        } else {
            throw new IllegalArgumentException("winnerPlayerId does not match battle players");
        }

        BattleMode mode = BattleMode.from(battle.getType());
        if (!mode.isRanked()) {
            battle.setWinner(winner);
            battle.setStatus("DONE");
            battle.setWinnerPointsDelta(0);
            battle.setLoserPointsDelta(0);
            System.out.printf("finalizeResult (Friendly): winner=%s – keine Trophäen%n", winner.getName());
            return;
        }

        // alle Ranks laden und nach min sortieren
        List<Rank> ranks = rankRepository.getAllRanks()
                .stream()
                .sorted(Comparator.comparingInt(Rank::getMin))
                .toList();

        Rank winnerRank = rankRepository.rankForPoints(winner.trophiesFor(mode), ranks);
        Rank loserRank  = rankRepository.rankForPoints(loser.trophiesFor(mode), ranks);

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

        // Trophäen nie unter 0
        int loserBefore = loser.trophiesFor(mode);
        loserDelta = Math.max(loserDelta, -loserBefore);
        winner.setTrophiesFor(mode, winner.trophiesFor(mode) + winnerDelta);
        loser.setTrophiesFor(mode, loserBefore + loserDelta);
        // Sieger verdient seinen Trophäen-Gewinn auch als Punkte (Währung)
        winner.setPoints(winner.getPoints() + Math.max(0, winnerDelta));

        battle.setWinner(winner);
        battle.setStatus("DONE");

        battle.setWinnerPointsDelta(winnerDelta);
        battle.setLoserPointsDelta(loserDelta);

        System.out.printf("finalizeResult (%s): winner=%s %+d, loser=%s %+d Trophäen%n",
                mode, winner.getName(), winnerDelta, loser.getName(), loserDelta);

    }



    public List<Battle> getIncomingBattles(String playerId) {
        return battleRepository.findIncoming(playerId);
    }

    public List<Battle> getOpenBattles(String playerId) {
        return battleRepository.findOpen(playerId);
    }

    @Transactional
    public String rankNameForPoints(int points) {
        List<Rank> ranks = rankRepository.getAllRanks()
                .stream()
                .sorted(Comparator.comparingInt(Rank::getMin))
                .toList();

        Rank r = rankRepository.rankForPoints(points, ranks);
        return r != null ? r.getName() : "Unranked";
    }

}
