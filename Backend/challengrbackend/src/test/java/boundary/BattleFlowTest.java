package boundary;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import control.BattleRepository;
import control.ChallengeRepository;
import control.ChallengeCategoriesRepository;
import entity.Battle;
import entity.Challenges;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Battle-Ablauf: Anfrage → Annehmen/Ablehnen/Abbrechen/Ablaufen, plus das JSON,
 * das der Empfänger bekommt.
 */
@QuarkusTest
class BattleFlowTest {

    private static final String FROM = "demo-1";
    private static final String TO = "demo-2";

    @Inject
    BattleService battleService;

    @Inject
    BattleRepository battleRepository;

    @Inject
    ChallengeRepository challengeRepository;

    @Inject
    ChallengeCategoriesRepository categoriesRepository;

    @Inject
    control.PlayerRepository playerRepository;

    private final ObjectMapper mapper = new ObjectMapper();

    /** Jeder Test startet ohne offene Anfragen (pro Spielerpaar ist nur eine erlaubt). */
    @BeforeEach
    void closeOpenRequests() {
        QuarkusTransaction.requiringNew().run(() ->
                battleRepository.update("status = 'EXPIRED' where status = 'REQUESTED'"));
    }

    private Battle newRequest() {
        return battleService.createRequestedBattle(FROM, TO, 1L);
    }

    private String statusOf(Long battleId) {
        return battleService.findById(battleId).getStatus();
    }

    private void ageBattle(Long battleId, int seconds) {
        QuarkusTransaction.requiringNew().run(() ->
                battleRepository.findById(battleId)
                        .setCreatedAt(LocalDateTime.now().minusSeconds(seconds)));
    }

    // ---------------------------------------------------------------- payload

    @Test
    void requestPayloadContainsTheStoredChallenge() throws Exception {
        Battle battle = newRequest();
        Challenges stored = challengeRepository.findById(1L);

        JsonNode json = mapper.readTree(GameSocket.buildBattleRequestedPayload(battle));

        assertEquals("battle-requested", json.get("type").asText());
        assertEquals(battle.getId().longValue(), json.get("battleId").asLong());
        assertEquals(1L, json.get("challengeId").asLong());
        assertEquals(stored.getText(), json.get("challengeText").asText());
        assertEquals("Fitness", json.get("challengeCategory").asText());
        assertEquals(FROM, json.get("fromPlayerId").asText());
        assertEquals(TO, json.get("toPlayerId").asText());
        assertTrue(json.get("expiresInSeconds").asLong() > 0);
    }

    @Test
    void requestPayloadStaysValidJsonWithSpecialCharacters() throws Exception {
        String text = "Sag \"Hallo\"\nund dann \\ rennen\t los";
        Long challengeId = QuarkusTransaction.requiringNew().call(() -> {
            Challenges ch = new Challenges();
            ch.setText(text);
            ch.setChallengeCategory(categoriesRepository.findByName("Customer"));
            return challengeRepository.create(ch).getId();
        });

        Battle battle = battleService.createRequestedBattle(FROM, TO, challengeId);
        JsonNode json = mapper.readTree(GameSocket.buildBattleRequestedPayload(battle));

        assertEquals(text, json.get("challengeText").asText());
        assertEquals("Customer", json.get("challengeCategory").asText());
    }

    // ------------------------------------------------------------- transitions

    @Test
    void receiverCanAcceptFreshRequest() {
        Battle battle = newRequest();

        assertNotNull(battleService.transitionFromRequested(battle.getId(), "ACCEPTED", TO));
        assertEquals("ACCEPTED", statusOf(battle.getId()));
    }

    @Test
    void senderCannotAcceptOwnRequest() {
        Battle battle = newRequest();

        assertNull(battleService.transitionFromRequested(battle.getId(), "ACCEPTED", FROM));
        assertEquals("REQUESTED", statusOf(battle.getId()));
    }

    @Test
    void senderCanCancelAndReceiverCanNoLongerAccept() {
        Battle battle = newRequest();

        assertNotNull(battleService.transitionFromRequested(battle.getId(), "CANCELLED", FROM));
        assertNull(battleService.transitionFromRequested(battle.getId(), "ACCEPTED", TO));
        assertEquals("CANCELLED", statusOf(battle.getId()));
    }

    @Test
    void receiverCannotCancel() {
        Battle battle = newRequest();

        assertNull(battleService.transitionFromRequested(battle.getId(), "CANCELLED", TO));
        assertEquals("REQUESTED", statusOf(battle.getId()));
    }

    @Test
    void cannotCancelAfterAccept() {
        Battle battle = newRequest();
        battleService.transitionFromRequested(battle.getId(), "ACCEPTED", TO);

        assertNull(battleService.transitionFromRequested(battle.getId(), "CANCELLED", FROM));
        assertEquals("ACCEPTED", statusOf(battle.getId()));
    }

    @Test
    void acceptingExpiredRequestFails() {
        Battle battle = newRequest();
        ageBattle(battle.getId(), (int) BattleService.REQUEST_TIMEOUT.toSeconds() + 5);

        assertNull(battleService.transitionFromRequested(battle.getId(), "ACCEPTED", TO));
        assertEquals("EXPIRED", statusOf(battle.getId()));
    }

    // ------------------------------------------------------ expiry + delivery

    @Test
    void staleRequestsExpire() {
        Battle stale = newRequest();
        ageBattle(stale.getId(), (int) BattleService.REQUEST_TIMEOUT.toSeconds() + 5);
        Battle fresh = newRequest();

        battleService.expireStaleRequests(LocalDateTime.now());

        // (der Scheduler kann schon vorher gelaufen sein – Ergebnis ist dasselbe)
        assertEquals("EXPIRED", statusOf(stale.getId()));
        assertEquals("REQUESTED", statusOf(fresh.getId()));
    }

    @Test
    void pendingRequestsAreRedeliveredOnlyWhileValid() {
        Battle old = newRequest();
        ageBattle(old.getId(), (int) BattleService.REQUEST_TIMEOUT.toSeconds() + 5);
        Battle cancelled = newRequest();
        battleService.transitionFromRequested(cancelled.getId(), "CANCELLED", FROM);
        Battle fresh = newRequest();

        var pendingIds = battleService.findPendingRequestsFor(TO, LocalDateTime.now())
                .stream().map(Battle::getId).toList();

        assertTrue(pendingIds.contains(fresh.getId()));
        assertFalse(pendingIds.contains(old.getId()));
        assertFalse(pendingIds.contains(cancelled.getId()));
        assertTrue(battleService.findPendingRequestsFor(FROM, LocalDateTime.now()).stream()
                .noneMatch(b -> b.getId().equals(fresh.getId())), "Nur an den Empfänger");
    }

    // ------------------------------------------------------ Regeln (Punkt 4)

    @Test
    void cannotChallengeYourself() {
        BattleRejectedException e = assertThrows(BattleRejectedException.class,
                () -> battleService.createRequestedBattle(FROM, FROM, 1L));
        assertTrue(e.getMessage().contains("selbst"));
    }

    @Test
    void onlyOneOpenRequestPerPair() {
        newRequest();

        assertThrows(BattleRejectedException.class, () -> battleService.createRequestedBattle(FROM, TO, 1L));
        assertThrows(BattleRejectedException.class, () -> battleService.createRequestedBattle(TO, FROM, 1L),
                "Auch in die andere Richtung");
    }

    @Test
    void newRequestAllowedAfterCancelOrExpiry() {
        Battle first = newRequest();
        battleService.transitionFromRequested(first.getId(), "CANCELLED", FROM);
        Battle second = newRequest();

        ageBattle(second.getId(), (int) BattleService.REQUEST_TIMEOUT.toSeconds() + 5);
        assertNotNull(newRequest(), "Abgelaufene Anfrage blockiert nicht");
    }

    // ------------------------------------------------ Ergebnis (Punkte 2 + 3)

    @Test
    void battleCanOnlyBeFinishedOnce() {
        Battle battle = newRequest();
        battleService.transitionFromRequested(battle.getId(), "ACCEPTED", TO);

        assertTrue(battleService.markDone(battle.getId()));
        assertFalse(battleService.markDone(battle.getId()), "Zweite Auswertung muss abgelehnt werden");
    }

    @Test
    void winnerIsChosenByIdEvenWithSameNames() {
        String[] ids = QuarkusTransaction.requiringNew().call(() -> {
            var a = new entity.Player("Max", 14.25, 48.26);
            a.setId("same-name-a");
            var b = new entity.Player("Max", 14.25, 48.26);
            b.setId("same-name-b");
            playerRepository.createPlayer(a);
            playerRepository.createPlayer(b);
            return new String[] { a.getId(), b.getId() };
        });

        Battle battle = battleService.createRequestedBattle(ids[0], ids[1], 1L);
        battleService.finalizeResult(battle.getId(), ids[1]);

        Battle done = battleService.findById(battle.getId());
        assertEquals(ids[1], done.getWinner().getId());
        assertTrue(done.getWinnerPointsDelta() > 0);
        assertTrue(done.getLoserPointsDelta() < 0);
    }

    @Test
    void voteByNameIsOnlyUsedWhenUnambiguous() throws Exception {
        Battle battle = newRequest();
        var byName   = mapper.readTree("{\"winnerName\":\"EigenerSpieler\"}");
        var byId     = mapper.readTree("{\"winnerId\":\"demo-2\",\"winnerName\":\"EigenerSpieler\"}");
        var foreign  = mapper.readTree("{\"winnerId\":\"3\"}");

        assertEquals(FROM, GameSocket.resolveVotedWinnerId(battle, byName, TO));
        assertEquals(TO, GameSocket.resolveVotedWinnerId(battle, byId, TO), "ID hat Vorrang vor dem Namen");
        assertNull(GameSocket.resolveVotedWinnerId(battle, foreign, TO), "Fremder Spieler kann nicht gewinnen");
    }

    @Test
    void requestCannotBeFinishedBeforeAccept() {
        Battle battle = newRequest();

        assertFalse(battleService.markDone(battle.getId()));
        assertEquals("REQUESTED", statusOf(battle.getId()));
    }

    // --------------------------------------------- hängende Battles (Punkt 3)

    private void setStatusChangedAgo(Long battleId, int minutes) {
        QuarkusTransaction.requiringNew().run(() ->
                battleRepository.findById(battleId).setStatusChangedAt(LocalDateTime.now().minusMinutes(minutes)));
    }

    @Test
    void stuckAcceptedBattleIsAbandoned() {
        Battle battle = newRequest();
        battleService.transitionFromRequested(battle.getId(), "ACCEPTED", TO);
        setStatusChangedAgo(battle.getId(), 11);

        battleService.abandonStaleBattles(LocalDateTime.now());

        assertEquals("ABANDONED", statusOf(battle.getId()));
        assertFalse(battleService.markDone(battle.getId()), "Abgebrochenes Battle bekommt kein Ergebnis mehr");
    }

    @Test
    void activeBattleWithRecentProgressStays() {
        Battle battle = newRequest();
        battleService.transitionFromRequested(battle.getId(), "ACCEPTED", TO);
        setStatusChangedAgo(battle.getId(), 11);
        battleService.updateStatus(battle.getId(), "READY_FOR_VOTING"); // Fortschritt → Zeit neu

        battleService.abandonStaleBattles(LocalDateTime.now());

        assertEquals("READY_FOR_VOTING", statusOf(battle.getId()));
    }

    @Test
    void finishedAndOpenBattlesAreNotAbandoned() {
        Battle done = newRequest();
        battleService.transitionFromRequested(done.getId(), "ACCEPTED", TO);
        battleService.markDone(done.getId());
        setStatusChangedAgo(done.getId(), 60);

        Battle open = newRequest();
        setStatusChangedAgo(open.getId(), 60);

        battleService.abandonStaleBattles(LocalDateTime.now());

        assertEquals("DONE", statusOf(done.getId()));
        assertNotEquals("ABANDONED", statusOf(open.getId()), "Anfragen laufen über ihr eigenes Timeout ab");
    }

    @Test
    void statusChangeUpdatesTimestamp() {
        Battle battle = newRequest();
        setStatusChangedAgo(battle.getId(), 30);

        battleService.transitionFromRequested(battle.getId(), "ACCEPTED", TO);

        LocalDateTime changed = battleService.findById(battle.getId()).getStatusChangedAt();
        assertTrue(changed.isAfter(LocalDateTime.now().minusMinutes(1)));
    }

    @Test
    void finalStatusesAreRecognized() {
        for (String s : java.util.List.of("DONE", "EXPIRED", "CANCELLED", "DECLINED", "ABANDONED")) {
            assertTrue(BattleService.isFinal(s), s);
        }
        for (String s : java.util.List.of("REQUESTED", "ACCEPTED", "READY_FOR_VOTING", "CHECKIN_DONE")) {
            assertFalse(BattleService.isFinal(s), s);
        }
        assertFalse(BattleService.isFinal(null));
    }
}
