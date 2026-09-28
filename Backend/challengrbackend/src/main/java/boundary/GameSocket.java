package boundary;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import entity.Battle;
import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.websocket.OnClose;
import jakarta.websocket.OnMessage;
import jakarta.websocket.OnOpen;
import jakarta.websocket.Session;
import jakarta.websocket.server.ServerEndpoint;

import java.io.IOException;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * WebSocket-Endpoint für Battles.
 * Verbinde z.B. mit: ws://localhost:8080/ws/game?playerId=1
 */
@ServerEndpoint("/ws/game")
@ApplicationScoped
public class GameSocket {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    // Merkt sich, welche Session zu welchem Player gehört
    private static final Map<String, Session> SESSIONS = new ConcurrentHashMap<>();
    // Mapping Session-ID -> Player-ID, damit wir beim Status-Update wissen, wer gesendet hat
    private static final Map<String, String> SESSION_TO_PLAYER = new ConcurrentHashMap<>();

    // Votes pro Battle: genau eine Stimme pro Spieler (Wert = Spieler-ID des Gewinners)
    private static final BattleVotes BATTLE_VOTES = new BattleVotes();

    // Messwerte der iPhone-Challenges (Sprint, Lautstärke, Kompass, Kamera, Schütteln, Liegestütze)
    private static final MetricResults METRIC_RESULTS = new MetricResults();

    /** So lange wird auf das Ergebnis des zweiten Spielers gewartet, dann wird trotzdem ausgewertet. */
    static final Duration DEFAULT_RESULT_WAIT = Duration.ofSeconds(45);
    /** Nur in Tests verkürzt. */
    static volatile Duration resultWait = DEFAULT_RESULT_WAIT;

    private static final ScheduledExecutorService RESULT_TIMEOUTS =
            Executors.newSingleThreadScheduledExecutor(appThreads("battle-result-timeouts"));

    /**
     * Eigener Pool für die Nachrichtenverarbeitung. Früher lief das über den Java-Standard-Pool
     * (CompletableFuture.runAsync ohne Executor) – dessen Threads haben den falschen Classloader
     * für Quarkus, was zu Fehlern und hängenden DB-Verbindungen führen kann.
     */
    private static final ExecutorService MESSAGE_WORKERS =
            Executors.newFixedThreadPool(8, appThreads("game-socket-worker"));

    private static ThreadFactory appThreads(String name) {
        ClassLoader appLoader = GameSocket.class.getClassLoader();
        AtomicInteger counter = new AtomicInteger();
        return r -> {
            Thread t = new Thread(r, name + "-" + counter.incrementAndGet());
            t.setDaemon(true);
            t.setContextClassLoader(appLoader);
            return t;
        };
    }

    /** Gewinner-Wert für "niemand hat gewonnen" (Unentschieden). */
    private static final String NOBODY = "";

    @Inject
    BattleService battleService;

    // ---------------------------------------------------------
    // Lifecycle
    // ---------------------------------------------------------

    @OnOpen
    public void onOpen(Session session) {
        // playerId aus Query-Param lesen: ?playerId=123
        var params = session.getRequestParameterMap().get("playerId");
        if (params == null || params.isEmpty()) {
            try {
                System.out.println("WebSocket rejected: missing playerId for session " + session.getId());
                session.close();
            } catch (IOException ignored) {}
            return;
        }
        String playerId = params.get(0);
        Session previousSession = SESSIONS.put(playerId, session);
        if (previousSession != null && !previousSession.getId().equals(session.getId())) {
            SESSION_TO_PLAYER.remove(previousSession.getId());
            try {
                if (previousSession.isOpen()) {
                    previousSession.close();
                }
            } catch (IOException ignored) {
            }
            System.out.println("Replaced existing WebSocket session for player " + playerId
                    + " (old=" + previousSession.getId() + ", new=" + session.getId() + ")");
        }
        SESSION_TO_PLAYER.put(session.getId(), playerId);
        System.out.println("WebSocket open for player " + playerId + " (session=" + session.getId() + ")");

        // Anfragen, die ankamen während der Spieler offline war, nachliefern
        CompletableFuture.runAsync(() -> deliverPendingRequests(playerId), MESSAGE_WORKERS);
    }

    @OnClose
    public void onClose(Session session) {
        // Session aus Maps entfernen
        SESSIONS.entrySet().removeIf(e -> e.getValue().getId().equals(session.getId()));
        SESSION_TO_PLAYER.remove(session.getId());
        System.out.println("WebSocket closed: " + session.getId());
    }

    @OnMessage
    public void onMessage(String message, Session session) {
        String playerId = SESSION_TO_PLAYER.get(session.getId());
        System.out.println("WebSocket message from player " + playerId + ": " + message);
        CompletableFuture.runAsync(() -> handleMessage(message, session, playerId), MESSAGE_WORKERS);
    }

    // ---------------------------------------------------------
    // Message Handling
    // ---------------------------------------------------------

    private void handleMessage(String message, Session session, String playerId) {
        try {
            JsonNode msg = MAPPER.readTree(message);
            String type = msg == null ? "" : msg.path("type").asText("");

            switch (type) {
                case "create-battle"        -> handleCreateBattle(msg, playerId);
                case "update-battle-status" -> handleUpdateBattleStatus(msg, playerId);
                case "battle-vote"          -> handleBattleVote(msg, playerId);
                case "battle-answer"        -> handleBattleAnswer(msg, playerId);
                case "sprint-result"        -> handleMetricResult(msg, playerId, MetricResults.Kind.SPRINT, "distance");
                case "loudness-result"      -> handleMetricResult(msg, playerId, MetricResults.Kind.LOUDNESS, "loudness");
                case "compass-result"       -> handleMetricResult(msg, playerId, MetricResults.Kind.COMPASS, "distance");
                case "camera-result"        -> handleMetricResult(msg, playerId, MetricResults.Kind.CAMERA, "score");
                case "shake-result"         -> handleMetricResult(msg, playerId, MetricResults.Kind.SHAKE, "shakes");
                case "pushup-result"        -> handleMetricResult(msg, playerId, MetricResults.Kind.PUSHUP, "reps");
                default -> sendError(session, "Unknown type");
            }
        } catch (Exception e) {
            e.printStackTrace();
            sendError(session, e.getMessage());
        }
    }


    // -------------------- create-battle ----------------------

    private void handleCreateBattle(JsonNode msg, String senderId) {
        String fromId    = playerIdField(msg, "fromId");
        String toId      = playerIdField(msg, "toId");
        Long challengeId = requireLong(msg, "challengeId");

        System.out.printf("create-battle received: from=%s, to=%s, challenge=%d%n",
                fromId, toId, challengeId);

        // Nur im eigenen Namen herausfordern
        if (senderId != null && fromId != null && !senderId.equals(fromId)) {
            sendBattleRejected(senderId, toId, "Ungültiger Absender");
            return;
        }

        Battle battle;
        try {
            battle = battleService.createRequestedBattle(fromId, toId, challengeId);
        } catch (BattleRejectedException e) {
            System.out.println("create-battle abgelehnt: " + e.getMessage());
            sendBattleRejected(senderId != null ? senderId : fromId, toId, e.getMessage());
            return;
        }

        System.out.printf("battle created: id=%d, status=%s, from=%s, to=%s%n",
                battle.getId(), battle.getStatus(),
                battle.getFromPlayer().getId(), battle.getToPlayer().getId());

        String payload = buildBattleRequestedPayload(battle);

        // an Herausgeforderten und Initiator schicken
        sendToPlayer(toId, payload);
        sendToPlayer(fromId, payload);

        // Bestätigung an den Initiator senden
        String confirmPayload = """
            {
              "type": "battle-created",
              "battleId": %d,
              "fromPlayerId": "%s",
              "toPlayerId": "%s",
              "challengeId": %d,
              "status": "%s"
            }
            """.formatted(
                battle.getId(),
                escapeJson(battle.getFromPlayer().getId()),
                escapeJson(battle.getToPlayer().getId()),
                battle.getChallenge().getId(),
                escapeJson(battle.getStatus())
        );
        sendToPlayer(fromId, confirmPayload);
    }

    private void sendBattleRejected(String playerId, String toId, String reason) {
        if (playerId == null) return;
        sendToPlayer(playerId, """
            {
              "type": "battle-rejected",
              "toPlayerId": "%s",
              "reason": "%s"
            }
            """.formatted(escapeJson(toId), escapeJson(reason)));
    }

    /** JSON für "battle-requested" (auch für erneute Zustellung nach Reconnect). */
    static String buildBattleRequestedPayload(Battle battle) {
        String categoryName = battle.getChallenge().getChallengeCategory() != null
                ? battle.getChallenge().getChallengeCategory().getName() : "";
        return """
    {
      "type": "battle-requested",
      "battleId": %d,
      "fromPlayerId": "%s",
      "toPlayerId": "%s",
      "challengeId": %d,
      "challengeText": "%s",
      "challengeCategory": "%s",
      "status": "%s",
      "expiresInSeconds": %d,
      "targetLatitude": %s,
      "targetLongitude": %s
    }
    """.formatted(
                battle.getId(),
                escapeJsonStatic(battle.getFromPlayer().getId()),
                escapeJsonStatic(battle.getToPlayer().getId()),
                battle.getChallenge().getId(),
                escapeJsonStatic(battle.getChallenge().getText()),
                escapeJsonStatic(categoryName),
                escapeJsonStatic(battle.getStatus()),
                secondsUntilExpiry(battle),
                battle.getTargetLatitude() != null ? battle.getTargetLatitude().toString() : "null",
                battle.getTargetLongitude() != null ? battle.getTargetLongitude().toString() : "null"
        );
    }

    static long secondsUntilExpiry(Battle battle) {
        if (battle.getCreatedAt() == null) return BattleService.REQUEST_TIMEOUT.toSeconds();
        long age = Duration.between(battle.getCreatedAt(), LocalDateTime.now()).toSeconds();
        return Math.max(0, BattleService.REQUEST_TIMEOUT.toSeconds() - age);
    }

    /** Offene Anfragen nach (Re-)Connect erneut zustellen – sonst gehen sie verloren. */
    private void deliverPendingRequests(String playerId) {
        try {
            for (Battle b : battleService.findPendingRequestsFor(playerId, LocalDateTime.now())) {
                sendToPlayer(playerId, buildBattleRequestedPayload(b));
            }
        } catch (Exception e) {
            System.out.println("deliverPendingRequests fehlgeschlagen für " + playerId + ": " + e.getMessage());
        }
    }

    // ---------------- update-battle-status -------------------

    private void handleUpdateBattleStatus(JsonNode msg, String senderId) {
        Long battleId = requireLong(msg, "battleId");
        String status = requireText(msg, "status");

        Battle battle;
        if ("ACCEPTED".equals(status) || "DECLINED".equals(status) || "CANCELLED".equals(status)) {
            // Nur aus REQUESTED erlaubt – verhindert Annehmen von abgebrochenen/abgelaufenen Anfragen
            battle = battleService.transitionFromRequested(battleId, status, senderId);
            if (battle == null) {
                Battle current = battleService.findById(battleId);
                String currentStatus = current != null ? current.getStatus() : "UNKNOWN";
                System.out.printf("Status %s für Battle %d abgelehnt (aktuell %s)%n", status, battleId, currentStatus);
                if (senderId != null) {
                    sendToPlayer(senderId, """
                    {
                      "type": "battle-updated",
                      "battleId": %d,
                      "status": "%s"
                    }
                    """.formatted(battleId, escapeJson(currentStatus)));
                }
                return;
            }
        } else {
            Battle current = battleService.findById(battleId);
            if (current == null) {
                System.out.println("update-battle-status: battle " + battleId + " nicht gefunden");
                return;
            }
            if (!isParticipant(current, senderId)) {
                System.out.printf("update-battle-status ignoriert: %s gehört nicht zu Battle %d%n", senderId, battleId);
                return;
            }
            battle = battleService.updateRunningStatus(battleId, status);
            if (battle == null) {
                System.out.printf("update-battle-status %s ignoriert: Battle %d läuft nicht (%s)%n",
                        status, battleId, current.getStatus());
                return;
            }
        }

        String payload = """
        {
          "type": "battle-updated",
          "battleId": %d,
          "status": "%s"
        }
        """.formatted(battle.getId(), escapeJson(battle.getStatus()));

        sendToPlayer(battle.getFromPlayer().getId(), payload);
        sendToPlayer(battle.getToPlayer().getId(), payload);

        // Sonderfall: Surrender → direkt Sieger/Verlierer bestimmen
        if ("DONE_SURRENDER".equals(status)) {
            handleSurrender(battle, senderId);
        }

        if ("ACCEPTED".equals(status) && isKnowledgeBattle(battle)) {
            sendKnowledgeQuestion(battle);
        }

        if ("CHECKIN_DONE".equals(status)) {
            handleCheckinDone(battle, senderId);
        }
    }

    /**
     * Wird aufgerufen, wenn einer der beiden Spieler DONE_SURRENDER sendet.
     * senderId ist der Spieler, der aufgegeben hat → der andere gewinnt.
     */
    private void handleSurrender(Battle battle, String senderId) {
        if (!isParticipant(battle, senderId)) {
            System.out.printf("Sender %s gehört nicht zu Battle %d%n", senderId, battle.getId());
            return;
        }

        String winnerId = otherPlayerId(battle, senderId);

        sendPendingToBoth(battle);

        // Ergebnis berechnen, speichern und an die beiden Spieler schicken
        computeAndBroadcastResult(battle, List.of(winnerId, winnerId));
    }

    // ---------------------- battle-vote ----------------------

    private void handleBattleVote(JsonNode msg, String voterId) {
        Long battleId = requireLong(msg, "battleId");

        Battle battle = battleService.findById(battleId);
        if (battle == null || voterId == null) {
            System.out.println("battle-vote ignoriert: battle=" + battleId + ", voter=" + voterId);
            return;
        }
        if (!isParticipant(battle, voterId)) {
            System.out.println("battle-vote ignoriert: Spieler " + voterId + " gehört nicht zu Battle " + battleId);
            return;
        }

        String winnerId = resolveVotedWinnerId(battle, msg, voterId);
        if (winnerId == null) {
            System.out.println("battle-vote ignoriert: Gewinner nicht eindeutig (" + msg + ")");
            return;
        }

        // Vote merken (doppelte Votes desselben Spielers werden ignoriert)
        List<String> votes = BATTLE_VOTES.register(battleId, voterId, winnerId);

        System.out.println("Received vote for battle " + battleId + " from " + voterId + ": " + winnerId
                + " (total votes: " + (votes != null ? votes.size() : BATTLE_VOTES.count(battleId)) + ")");

        // Sobald beide Spieler abgestimmt haben → pending + Ergebnis/Strafe
        if (votes != null) {
            sendPendingToBoth(battle);
            computeAndBroadcastResult(battle, votes);
        }
    }

    /**
     * Gewinner eines Votes als Spieler-ID.
     * Neue Clients schicken "winnerId"; ältere nur "winnerName" – der wird nur akzeptiert,
     * wenn er eindeutig zu einem der beiden Spieler passt.
     */
    static String resolveVotedWinnerId(Battle battle, JsonNode msg, String voterId) {
        String fromId = battle.getFromPlayer().getId();
        String toId   = battle.getToPlayer().getId();

        String winnerId = msg.path("winnerId").asText(null);
        if (winnerId != null && (winnerId.equals(fromId) || winnerId.equals(toId))) {
            return winnerId;
        }

        String winnerName = msg.path("winnerName").asText(null);
        if (winnerName == null) return null;

        boolean isFrom = winnerName.equals(battle.getFromPlayer().getName());
        boolean isTo   = winnerName.equals(battle.getToPlayer().getName());
        if (isFrom && !isTo) return fromId;
        if (isTo && !isFrom) return toId;
        return null; // gleiche Namen oder unbekannt → nicht raten
    }

    // -------------------- Ergebnis + Strafe ------------------

    /**
     * Wertet ein Battle aus und schickt battle-result an die beiden Spieler.
     *
     * @param winnerIdVotes Spieler-IDs der Gewinner-Stimmen:
     *                      eine Stimme = feststehender Gewinner,
     *                      zwei gleiche = Einigung, zwei verschiedene = Konflikt,
     *                      NOBODY = Unentschieden.
     */
    private void computeAndBroadcastResult(Battle battle, List<String> winnerIdVotes) {
        Long battleId = battle.getId();

        // Nur die erste Auswertung zählt (verhindert doppelte Punkte)
        if (!battleService.markDone(battleId)) {
            System.out.println("Battle " + battleId + " ist schon ausgewertet – ignoriere weitere Auswertung.");
            return;
        }

        String fromId = battle.getFromPlayer().getId();
        String toId   = battle.getToPlayer().getId();

        String winnerId = null;
        boolean isConflict = false;

        if (winnerIdVotes != null && winnerIdVotes.size() >= 2) {
            String v1 = winnerIdVotes.get(0);
            String v2 = winnerIdVotes.get(1);
            if (Objects.equals(v1, v2)) {
                winnerId = v1;
            } else {
                isConflict = true;
            }
        } else if (winnerIdVotes != null && winnerIdVotes.size() == 1) {
            winnerId = winnerIdVotes.get(0);
        }

        if (winnerId != null && !winnerId.equals(fromId) && !winnerId.equals(toId)) {
            winnerId = null; // NOBODY / unbekannt → Unentschieden
        }

        String loserId = null;
        String winnerName = "Niemand";
        String loserName  = "Niemand";
        int winnerDelta = 0;
        int loserDelta  = 0;
        String trashTalk;

        if (!isConflict && winnerId != null) {
            loserId = otherPlayerId(battle, winnerId);
            winnerName = playerName(battle, winnerId);
            loserName  = playerName(battle, loserId);
            try {
                battleService.finalizeResult(battleId, winnerId);
                Battle updated = battleService.findById(battleId);
                winnerDelta = Optional.ofNullable(updated.getWinnerPointsDelta()).orElse(0);
                loserDelta  = Optional.ofNullable(updated.getLoserPointsDelta()).orElse(0);
            } catch (Exception e) {
                e.printStackTrace();
                System.out.println("Fehler beim finalisieren von Battle " + battleId + ": " + e.getMessage());
            }

            trashTalk = "GG!";
            resetConflictCountersForBattle(battle);

        } else if (isConflict) {
            // Konflikt → Strafe anwenden, Deltas als Konflikt-Penalty anzeigen
            int[] penalties = applyConflictPenalty(battle);
            int shownPenalty = Math.max(penalties[0], penalties[1]);  // z.B. 0, 10, 20 ...

            winnerDelta = shownPenalty > 0 ? -shownPenalty : 0;
            loserDelta  = shownPenalty > 0 ? -shownPenalty : 0;

            trashTalk = "Keine Einigung – Konflikt-Penalty.";
        } else {
            trashTalk = "Unentschieden!";
        }

        String metricsJson = buildMetricsJson(battle, winnerId, loserId);

        String payload = """
        {
            "type": "battle-result",
            "battleId": %d,
            "winnerId": %s,
            "winnerName": "%s",
            "winnerAvatar": "opponentAvatar",
            "winnerPointsDelta": %d,
            "loserId": %s,
            "loserName": "%s",
            "loserAvatar": "ownAvatar",
            "loserPointsDelta": %d,
            "trashTalk": "%s"%s
        }
        """.formatted(
                battleId,
                jsonStringOrNull(winnerId),
                escapeJson(winnerName),
                winnerDelta,
                jsonStringOrNull(loserId),
                escapeJson(loserName),
                loserDelta,
                escapeJson(trashTalk),
                metricsJson
        );

        // Nur an die beiden Spieler dieses Battles – nicht an alle Verbundenen
        sendToPlayer(fromId, payload);
        sendToPlayer(toId, payload);

        clearBattleState(battleId);
        System.out.println("Sent battle-result for battle " + battleId + ": " + payload);
    }

    private void clearBattleState(Long battleId) {
        clearBattleStateStatic(battleId);
    }

    private String buildMetricsJson(Battle battle, String winnerId, String loserId) {
        if (winnerId == null || loserId == null) {
            return "";
        }

        Long battleId = battle.getId();
        MetricResults.Kind kind = METRIC_RESULTS.kind(battleId);
        if (kind == null) {
            return "";
        }

        Double winnerValue = METRIC_RESULTS.value(battleId, winnerId);
        Double loserValue  = METRIC_RESULTS.value(battleId, loserId);
        if (winnerValue == null || loserValue == null) {
            return ""; // ein Spieler hat nichts geschickt → keine Vergleichswerte anzeigen
        }

        String entry = kind.integer
                ? "\"%s\": {\"winner\": %d, \"loser\": %d}".formatted(
                        kind.key, Math.round(winnerValue), Math.round(loserValue))
                : "\"%s\": {\"winner\": %s, \"loser\": %s}".formatted(
                        kind.key,
                        String.format(Locale.US, "%.2f", winnerValue),
                        String.format(Locale.US, "%.2f", loserValue));

        return """
,
      "metrics": {
      %s
      }
""".formatted(entry);
    }

    private int applyConflictToPlayer(Player player) {
        int current = player.getConsecutiveConflicts();
        current += 1;
        player.setConsecutiveConflicts(current);

        int penalty = 0;
        if (current >= 3) {
            penalty = (current - 2) * 10;  // 3 -> 10, 4 -> 20, ...
        }

        if (penalty > 0) {
            player.setPoints(player.getPoints() - penalty);
            System.out.printf("Konflikt-Penalty für %s: -%d Punkte (Konflikte in Folge: %d)%n",
                    player.getName(), penalty, current);
        } else {
            System.out.printf("Konflikt ohne Penalty für %s (Konflikte in Folge: %d)%n",
                    player.getName(), current);
        }

        battleService.updatePlayer(player);
        return penalty;
    }

    private int[] applyConflictPenalty(Battle battle) {
        Player fromPlayer = battle.getFromPlayer();
        Player toPlayer   = battle.getToPlayer();

        int pFrom = applyConflictToPlayer(fromPlayer);
        int pTo   = applyConflictToPlayer(toPlayer);

        return new int[] { pFrom, pTo };
    }


    private void resetConflictCountersForBattle(Battle battle) {
        Player fromPlayer = battle.getFromPlayer();
        Player toPlayer   = battle.getToPlayer();

        fromPlayer.setConsecutiveConflicts(0);
        toPlayer.setConsecutiveConflicts(0);

        battleService.updatePlayer(fromPlayer);
        battleService.updatePlayer(toPlayer);
    }

    // ---------------------------------------------------------
    // Hilfsfunktionen
    // ---------------------------------------------------------

    /** Angenommen und noch nicht beendet. */
    private static boolean isRunning(Battle battle) {
        return !BattleService.isFinal(battle.getStatus()) && !"REQUESTED".equals(battle.getStatus());
    }

    /** Für den Timeout-Job: Zwischenstände eines abgebrochenen Battles verwerfen. */
    static void clearBattleStateStatic(Long battleId) {
        METRIC_RESULTS.clear(battleId);
        BATTLE_VOTES.clear(battleId);
        BATTLE_ANSWERS.remove(battleId);
    }

    private static boolean isParticipant(Battle battle, String playerId) {
        return playerId != null
                && (playerId.equals(battle.getFromPlayer().getId()) || playerId.equals(battle.getToPlayer().getId()));
    }

    private static String otherPlayerId(Battle battle, String playerId) {
        String fromId = battle.getFromPlayer().getId();
        return fromId.equals(playerId) ? battle.getToPlayer().getId() : fromId;
    }

    private static String playerName(Battle battle, String playerId) {
        return battle.getFromPlayer().getId().equals(playerId)
                ? battle.getFromPlayer().getName()
                : battle.getToPlayer().getName();
    }

    private void sendPendingToBoth(Battle battle) {
        String pendingPayload = """
        {
          "type": "battle-pending",
          "battleId": %d
        }
        """.formatted(battle.getId());

        sendToPlayer(battle.getFromPlayer().getId(), pendingPayload);
        sendToPlayer(battle.getToPlayer().getId(), pendingPayload);
    }

    private void sendToPlayer(String playerId, String jsonPayload) {
        // Instance wrapper for existing call sites.
        sendToPlayerStatic(playerId, jsonPayload);
    }

    /**
     * Allows other components (e.g. REST resources) to push messages to players.
     */
    public static void sendToPlayerStatic(String playerId, String jsonPayload) {
        if (playerId == null) return;
        Session s = SESSIONS.get(playerId);
        if (s != null && s.isOpen()) {
            System.out.println("Sending WS payload to player " + playerId + ": " + jsonPayload);
            s.getAsyncRemote().sendText(jsonPayload);
        } else {
            System.out.println("No active WebSocket session for player " + playerId + ". Payload not delivered: " + jsonPayload);
        }
    }

    // ---------------------------------------------------------
    // Real-time events (friends + positions)
    // ---------------------------------------------------------

    public static void emitFriendRequestCreated(Long requestId, String fromPlayerId, String toPlayerId) {
        String payload = """
            {
              \"type\": \"friend-request-created\",
              \"requestId\": %d,
              \"fromPlayerId\": \"%s\",
              \"toPlayerId\": \"%s\"
            }
            """.formatted(requestId, escapeJsonStatic(fromPlayerId), escapeJsonStatic(toPlayerId));
        sendToPlayerStatic(fromPlayerId, payload);
        sendToPlayerStatic(toPlayerId, payload);
    }

    public static void emitFriendRequestUpdated(Long requestId, String fromPlayerId, String toPlayerId, String status) {
        String payload = """
            {
              \"type\": \"friend-request-updated\",
              \"requestId\": %d,
              \"fromPlayerId\": \"%s\",
              \"toPlayerId\": \"%s\",
              \"status\": \"%s\"
            }
            """.formatted(
                requestId,
                escapeJsonStatic(fromPlayerId),
                escapeJsonStatic(toPlayerId),
                escapeJsonStatic(status)
        );
        sendToPlayerStatic(fromPlayerId, payload);
        sendToPlayerStatic(toPlayerId, payload);
    }

    public static void emitFriendRemoved(String playerId, String friendId) {
        String payload = """
            {
              \"type\": \"friend-removed\",
              \"playerId\": \"%s\",
              \"friendId\": \"%s\"
            }
            """.formatted(escapeJsonStatic(playerId), escapeJsonStatic(friendId));
        sendToPlayerStatic(playerId, payload);
        sendToPlayerStatic(friendId, payload);
    }

    /**
     * "Spieler hat sich bewegt" – nur an Spieler in der Nähe und ohne Koordinaten.
     * Die Apps laden danach selbst die Spieler in ihrem Radius (Datenschutz: niemand
     * bekommt die genaue Position von Spielern, die weit weg sind).
     */
    public static void emitPlayerPositionUpdated(String playerId, Collection<String> recipientIds) {
        String payload = buildPlayerPositionPayload(playerId);
        for (String recipient : recipientIds) {
            if (recipient == null || recipient.equals(playerId)) continue;
            Session s = SESSIONS.get(recipient);
            if (s != null && s.isOpen()) {
                s.getAsyncRemote().sendText(payload);
            }
        }
    }

    static String buildPlayerPositionPayload(String playerId) {
        return """
            {
              \"type\": \"player-position-updated\",
              \"playerId\": \"%s\"
            }
            """.formatted(escapeJsonStatic(playerId));
    }

    static String escapeJsonStatic(String s) {
        if (s == null) return "";
        StringBuilder sb = new StringBuilder(s.length() + 8);
        for (char c : s.toCharArray()) {
            switch (c) {
                case '"'  -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) sb.append(String.format("\\u%04x", (int) c));
                    else sb.append(c);
                }
            }
        }
        return sb.toString();
    }

    private static String jsonStringOrNull(String s) {
        return s == null ? "null" : "\"" + escapeJsonStatic(s) + "\"";
    }

    private void sendError(Session session, String msg) {
        if (session != null && session.isOpen()) {
            System.out.println("Sending WS error to session " + session.getId() + ": " + msg);
            session.getAsyncRemote().sendText("""
                { "type": "error", "message": "%s" }
                """.formatted(escapeJson(msg == null ? "Unknown error" : msg)));
        }
    }

    private String escapeJson(String s) {
        return escapeJsonStatic(s);
    }

    // ---- Felder aus eingehenden Nachrichten lesen (Jackson) ----

    static Long requireLong(JsonNode msg, String key) {
        JsonNode node = msg.get(key);
        if (node == null || node.isNull()) throw new IllegalArgumentException("Missing field: " + key);
        if (node.isNumber()) return node.asLong();
        try {
            return Long.valueOf(node.asText().trim());
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Invalid number for " + key + ": " + node);
        }
    }

    static double requireDouble(JsonNode msg, String key) {
        JsonNode node = msg.get(key);
        if (node == null || node.isNull()) throw new IllegalArgumentException("Missing field: " + key);
        if (node.isNumber()) return node.asDouble();
        try {
            return Double.parseDouble(node.asText().trim());
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Invalid number for " + key + ": " + node);
        }
    }

    static String requireText(JsonNode msg, String key) {
        JsonNode node = msg.get(key);
        if (node == null || node.isNull()) throw new IllegalArgumentException("Missing field: " + key);
        return node.asText();
    }

    /** Spieler-IDs kommen als String (Keycloak) oder bei alten Clients als Zahl. */
    static String playerIdField(JsonNode msg, String key) {
        JsonNode node = msg.get(key);
        if (node == null || node.isNull()) return null;
        return node.asText();
    }

    // ---------------------------------------------------------
    // Wissen
    // ---------------------------------------------------------

    private static final Map<Long, Map<String, Integer>> BATTLE_ANSWERS = new ConcurrentHashMap<>();

    private void handleBattleAnswer(JsonNode msg, String playerId) {
        Long battleId   = requireLong(msg, "battleId");
        int answerIndex = requireLong(msg, "answerIndex").intValue();

        if (playerId == null) {
            System.out.println("battle-answer ohne playerId, ignoriere");
            return;
        }

        Battle battle = battleService.findById(battleId);
        if (battle == null) {
            System.out.println("battle-answer: battle " + battleId + " nicht gefunden");
            return;
        }
        if (!isParticipant(battle, playerId)) {
            System.out.println("battle-answer: " + playerId + " gehört nicht zu Battle " + battleId);
            return;
        }

        // Nur für Wissen-Battles nutzen wir diese Logik
        if (!isKnowledgeBattle(battle)) {
            System.out.println("battle-answer ignoriert, kein Wissen-Battle");
            return;
        }

        Integer correctIndex = battle.getChallenge().getCorrectIndex();
        if (correctIndex == null) {
            System.out.println("battle-answer: correctIndex null, breche ab");
            return;
        }

        // Wenn Battle schon DONE, keine Antworten mehr akzeptieren
        if (!isRunning(battle)) {
            System.out.println("battle-answer: Battle " + battleId + " läuft nicht (" + battle.getStatus() + "), ignoriere");
            return;
        }

        boolean isCorrect = (answerIndex == correctIndex);

        // Antwort speichern (falls du später Stats brauchst)
        BATTLE_ANSWERS
                .computeIfAbsent(battleId, id -> new ConcurrentHashMap<>())
                .put(playerId, answerIndex);

        System.out.printf("battle-answer: battle %d, player %s -> %d (korrekt=%s)%n",
                battleId, playerId, answerIndex, isCorrect);

        if (isCorrect) {
            // Der erste, der korrekt ist, gewinnt sofort
            sendPendingToBoth(battle);
            computeAndBroadcastResult(battle, List.of(playerId));
        } else {
            // Falsche Antwort: einfach ignorieren, anderer kann noch gewinnen
            System.out.println("battle-answer: falsche Antwort, Battle läuft weiter");
        }
    }

    private boolean isKnowledgeBattle(Battle battle) {
        if (battle == null || battle.getChallenge() == null || battle.getChallenge().getChallengeCategory() == null) {
            return false;
        }
        String name = battle.getChallenge().getChallengeCategory().getName();
        return "Wissen".equalsIgnoreCase(name);
    }

    private void sendKnowledgeQuestion(Battle battle) {
        var challenge = battle.getChallenge();

        String json = """
    {
      "type": "battle-question",
      "battleId": %d,
      "challenge": {
        "id": %d,
        "text": "%s",
        "category": "%s",
        "choices": ["%s","%s","%s","%s"]
      }
    }
    """.formatted(
                battle.getId(),
                challenge.getId(),
                escapeJson(challenge.getText()),
                escapeJson(challenge.getChallengeCategory().getName()),
                escapeJson(challenge.getOptionA()),
                escapeJson(challenge.getOptionB()),
                escapeJson(challenge.getOptionC()),
                escapeJson(challenge.getOptionD())
        );
        // correctIndex wird bewusst NICHT mitgeschickt – das Backend prüft die Antwort selbst.

        sendToPlayer(battle.getFromPlayer().getId(), json);
        sendToPlayer(battle.getToPlayer().getId(), json);
    }

    // ---------------------------------------------------------
    // Check-In-Spot
    // ---------------------------------------------------------

    private void handleCheckinDone(Battle battle, String senderId) {
        if (!isParticipant(battle, senderId)) {
            System.out.printf("CHECKIN_DONE: sender %s gehört nicht zu Battle %d%n",
                    senderId, battle.getId());
            return;
        }

        // Wer zuerst eincheckt, gewinnt
        sendPendingToBoth(battle);
        computeAndBroadcastResult(battle, List.of(senderId));
    }

    // ---------------------------------------------------------
    // Messwert-Challenges (Sprint, Lautstärke, Kompass, Kamera, Schütteln, Liegestütze)
    // ---------------------------------------------------------

    /**
     * Speichert den Messwert eines Spielers. Sobald beide Werte da sind, wird ausgewertet.
     * Fehlt der zweite Wert nach resultWait, wird trotzdem ausgewertet
     * (fehlender Wert = schlechtester Wert), damit niemand ewig wartet.
     */
    private void handleMetricResult(JsonNode msg, String playerId, MetricResults.Kind kind, String valueField) {
        Long battleId = requireLong(msg, "battleId");
        double value  = requireDouble(msg, valueField);

        System.out.println("➡️ " + kind.key + "-result: battleId=" + battleId + ", value=" + value + ", player=" + playerId);

        Battle battle = battleService.findById(battleId);
        if (battle == null) {
            System.out.println(kind.key + "-result: battle " + battleId + " nicht gefunden");
            return;
        }
        if (!isParticipant(battle, playerId)) {
            System.out.println(kind.key + "-result: " + playerId + " gehört nicht zu Battle " + battleId);
            return;
        }
        if (!isRunning(battle)) {
            System.out.println(kind.key + "-result: Battle " + battleId + " läuft nicht (" + battle.getStatus() + ")");
            return;
        }

        String fromId = battle.getFromPlayer().getId();
        String toId   = battle.getToPlayer().getId();

        boolean bothThere = METRIC_RESULTS.record(battleId, kind, playerId, value, fromId, toId);
        if (bothThere) {
            evaluateMetricBattle(battleId);
            return;
        }

        System.out.println(kind.key + "-result von " + playerId + " gespeichert, warte auf Gegner...");
        sendToPlayer(playerId, "{\"type\":\"battle-pending\",\"battleId\":" + battleId + "}");

        RESULT_TIMEOUTS.schedule(() -> {
            try {
                evaluateMetricBattle(battleId);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }, resultWait.toMillis(), TimeUnit.MILLISECONDS);
    }

    private void evaluateMetricBattle(Long battleId) {
        Battle battle = battleService.findById(battleId);
        if (battle == null || !isRunning(battle) || METRIC_RESULTS.kind(battleId) == null) {
            return; // schon ausgewertet (z.B. beide Werte kamen vor dem Timeout)
        }

        String fromId = battle.getFromPlayer().getId();
        String toId   = battle.getToPlayer().getId();

        MetricResults.Outcome outcome = METRIC_RESULTS.decide(battleId, fromId, toId);
        System.out.println("✅ " + METRIC_RESULTS.kind(battleId).key + " ausgewertet für Battle " + battleId
                + ": from=" + METRIC_RESULTS.value(battleId, fromId)
                + ", to=" + METRIC_RESULTS.value(battleId, toId) + " -> " + outcome);

        sendPendingToBoth(battle);

        List<String> votes = switch (outcome) {
            case FROM_WINS -> List.of(fromId);
            case TO_WINS   -> List.of(toId);
            case CONFLICT  -> List.of(fromId, toId);   // bestehendes Konfliktsystem greift
            case DRAW      -> List.of(NOBODY);
        };
        computeAndBroadcastResult(battle, votes);
    }
}
