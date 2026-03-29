package boundary;

import entity.Battle;
import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.websocket.OnClose;
import jakarta.websocket.OnMessage;
import jakarta.websocket.OnOpen;
import jakarta.websocket.Session;
import jakarta.websocket.server.ServerEndpoint;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;

/**
 * WebSocket-Endpoint für Battles.
 * Verbinde z.B. mit: ws://localhost:8080/ws/game?playerId=1
 */
@ServerEndpoint("/ws/game")
@ApplicationScoped
public class GameSocket {

    // Merkt sich, welche Session zu welchem Player gehört
    private static final Map<Long, Session> SESSIONS = new ConcurrentHashMap<>();
    // Mapping Session-ID -> Player-ID, damit wir beim Status-Update wissen, wer gesendet hat
    private static final Map<String, Long> SESSION_TO_PLAYER = new ConcurrentHashMap<>();

    // Votes pro Battle: battleId -> Liste der Gewinner-Namen
    private static final Map<Long, List<String>> BATTLE_VOTES = new ConcurrentHashMap<>();

    private static final Map<Long, Map<Long, Double>> SPRINT_RESULTS = new ConcurrentHashMap<>();
    
    private static final Map<Long, Map<Long, Double>> LOUDNESS_RESULTS = new ConcurrentHashMap<>();

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
        Long playerId = Long.valueOf(params.get(0));
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
        Long playerId = SESSION_TO_PLAYER.get(session.getId());
        System.out.println("WebSocket message from player " + playerId + ": " + message);
        CompletableFuture.runAsync(() -> handleMessage(message, session, playerId));
    }

    // ---------------------------------------------------------
    // Message Handling
    // ---------------------------------------------------------

    private void handleMessage(String message, Session session, Long playerId) {
        try {
            if (message.contains("\"type\":\"create-battle\"")) {
                handleCreateBattle(message);

            } else if (message.contains("\"type\":\"update-battle-status\"")) {
                handleUpdateBattleStatus(message, playerId);

            } else if (message.contains("\"type\":\"battle-vote\"")) {
                handleBattleVote(message);

            } else if (message.contains("\"type\":\"battle-answer\"")) {
                handleBattleAnswer(message, playerId);   // ⬅️ HINZUFÜGEN

            } else if (message.contains("\"type\":\"sprint-result\"")) { // NEU
                handleSprintResult(message, playerId);

            } else if (message.contains("\"type\":\"loudness-result\"")) { // NEU
                handleLoudnessResult(message, playerId);

            } else {
                sendError(session, "Unknown type");
            }
        } catch (Exception e) {
            e.printStackTrace();
            sendError(session, e.getMessage());
        }
    }


    // -------------------- create-battle ----------------------

    private void handleCreateBattle(String message) {
        Long fromId      = extractLong(message, "fromId");
        Long toId        = extractLong(message, "toId");
        Long challengeId = extractLong(message, "challengeId");

    System.out.printf("create-battle received: from=%d, to=%d, challenge=%d%n",
        fromId, toId, challengeId);

        Battle battle = battleService.createRequestedBattle(fromId, toId, challengeId);

    System.out.printf("battle created: id=%d, status=%s, from=%d, to=%d%n",
        battle.getId(), battle.getStatus(),
        battle.getFromPlayer().getId(), battle.getToPlayer().getId());

        String payload = """
    {
      "type": "battle-requested",
      "battleId": %d,
      "fromPlayerId": %d,
      "toPlayerId": %d,
      "challengeId": %d,
      "status": "%s",
      "targetLatitude": %s,
      "targetLongitude": %s
    }
    """.formatted(
                battle.getId(),
                battle.getFromPlayer().getId(),
                battle.getToPlayer().getId(),
                battle.getChallenge().getId(),
                battle.getStatus(),
                battle.getTargetLatitude() != null ? battle.getTargetLatitude().toString() : "null",
                battle.getTargetLongitude() != null ? battle.getTargetLongitude().toString() : "null"
        );


        // an Herausgeforderten und Initiator schicken
        sendToPlayer(toId, payload);
        sendToPlayer(fromId, payload);

        // Bestätigung an den Initiator senden
        String confirmPayload = """
            {
              "type": "battle-created",
              "battleId": %d,
              "fromPlayerId": %d,
              "toPlayerId": %d,
              "challengeId": %d,
              "status": "%s"
            }
            """.formatted(
                battle.getId(),
                battle.getFromPlayer().getId(),
                battle.getToPlayer().getId(),
                battle.getChallenge().getId(),
                battle.getStatus()
        );
        sendToPlayer(fromId, confirmPayload);
    }

    // ---------------- update-battle-status -------------------

    private void handleUpdateBattleStatus(String message, Long senderId) {
        Long battleId = extractLong(message, "battleId");
        String status = extractString(message, "status");

        Battle battle = battleService.updateStatus(battleId, status);

        String payload = """
        {
          "type": "battle-updated",
          "battleId": %d,
          "status": "%s"
        }
        """.formatted(battle.getId(), battle.getStatus());

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
    private void handleSurrender(Battle battle, Long senderId) {
        if (senderId == null) {
            System.out.println("handleSurrender: senderId null, ignoriere.");
            return;
        }

        Long fromId = battle.getFromPlayer().getId();
        Long toId   = battle.getToPlayer().getId();

        String winnerName;
        String loserName;

        // Wenn der Angreifer (from) surrendered, gewinnt der Verteidiger (to)
        if (Objects.equals(senderId, fromId)) {
            winnerName = battle.getToPlayer().getName();
            loserName  = battle.getFromPlayer().getName();
        }
        // Wenn der Verteidiger (to) surrendered, gewinnt der Angreifer (from)
        else if (Objects.equals(senderId, toId)) {
            winnerName = battle.getFromPlayer().getName();
            loserName  = battle.getToPlayer().getName();
        } else {
            System.out.printf("Sender %d gehört nicht zu Battle %d%n", senderId, battle.getId());
            return;
        }

        // Zwei "Votes" für den Gewinner simulieren
        List<String> votes = List.of(winnerName, winnerName);

        // pending-Event nur an die beiden Spieler schicken
        String pendingPayload = """
        {
          "type": "battle-pending",
          "battleId": %d
        }
        """.formatted(battle.getId());

        sendToPlayer(fromId, pendingPayload);
        sendToPlayer(toId, pendingPayload);

        // Ergebnis berechnen, speichern und als battle-result an alle schicken
        computeAndBroadcastResult(battle, votes);
    }

    // ---------------------- battle-vote ----------------------

    private void handleBattleVote(String message) {
        Long battleId = extractLong(message, "battleId");
        String winner = extractString(message, "winnerName");

        // Vote merken
        BATTLE_VOTES.computeIfAbsent(battleId, id -> new ArrayList<>()).add(winner);
        List<String> votes = BATTLE_VOTES.get(battleId);

        System.out.println("Received vote for battle " + battleId + ": " + winner
                + " (total votes: " + votes.size() + ")");

        // Sobald 2 Votes da sind → pending + Ergebnis/Strafe
        if (votes.size() >= 2) {
            Battle battle = battleService.findById(battleId);

            String pendingPayload = """
            {
              "type": "battle-pending",
              "battleId": %d
            }
            """.formatted(battleId);

            sendToPlayer(battle.getFromPlayer().getId(), pendingPayload);
            sendToPlayer(battle.getToPlayer().getId(), pendingPayload);

            computeAndBroadcastResult(battle, votes);
            BATTLE_VOTES.remove(battleId);
        }
    }

    // -------------------- Ergebnis + Strafe ------------------

    private void computeAndBroadcastResult(Battle battle, List<String> votes) {
        Long battleId = battle.getId();

        String winnerName = null;
        String loserName  = null;
        boolean isConflict = false;

        if (votes != null && votes.size() >= 2) {
            String v1 = votes.get(0);
            String v2 = votes.get(1);

            if (v1.equals(v2)) {
                // Einigung
                winnerName = v1;
                loserName  = otherPlayerName(battle, winnerName);
            } else {
                // Konflikt
                isConflict = true;
            }
        } else if (votes != null && votes.size() == 1) {
            // z.B. Surrender: ein WinnerName
            winnerName = votes.get(0);
            loserName  = otherPlayerName(battle, winnerName);
        }

        int winnerDelta = 0;
        int loserDelta  = 0;
        String trashTalk = "GG!";

        if (!isConflict && winnerName != null && loserName != null) {
            // normaler Sieg → wie vorher, aber mit deinen BattleService-Deltas
            try {
                battleService.finalizeResult(battleId, winnerName);
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

            battleService.updateStatus(battleId, "DONE");
            int[] penalties = applyConflictPenalty(battle);
            int penaltyFrom = penalties[0];
            int penaltyTo   = penalties[1];

            winnerName = "Niemand";
            loserName  = "Niemand";

            int shownPenalty = Math.max(penaltyFrom, penaltyTo);  // z.B. 0, 10, 20 ...

            winnerDelta = shownPenalty > 0 ? -shownPenalty : 0;
            loserDelta  = shownPenalty > 0 ? -shownPenalty : 0;

            trashTalk = "Keine Einigung – Konflikt-Penalty.";
        }


        String payload = """
    {
      "type": "battle-result",
      "battleId": %d,
      "winnerName": "%s",
      "winnerAvatar": "opponentAvatar",
      "winnerPointsDelta": %d,
      "loserName": "%s",
      "loserAvatar": "ownAvatar",
      "loserPointsDelta": %d,
      "trashTalk": "%s"
    }
    """.formatted(
                battleId,
                escapeJson(winnerName != null ? winnerName : "Niemand"),
                winnerDelta,
                escapeJson(loserName != null ? loserName : "Niemand"),
                loserDelta,
                escapeJson(trashTalk)
        );

        SESSIONS.values().forEach(s -> {
            if (s.isOpen()) {
                s.getAsyncRemote().sendText(payload);
            }
        });

        System.out.println("Sent battle-result for battle " + battleId + ": " + payload);
    }

    private String otherPlayerName(Battle battle, String winnerName) {
        String fromName = battle.getFromPlayer().getName();
        String toName   = battle.getToPlayer().getName();
        return fromName.equals(winnerName) ? toName : fromName;
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

        // TODO: an deine Persistenz anpassen
        battleService.updatePlayer(fromPlayer);
        battleService.updatePlayer(toPlayer);
    }

    // ---------------------------------------------------------
    // Hilfsfunktionen
    // ---------------------------------------------------------

    private void sendToPlayer(Long playerId, String jsonPayload) {
        Session s = SESSIONS.get(playerId);
        if (s != null && s.isOpen()) {
            System.out.println("Sending WS payload to player " + playerId + ": " + jsonPayload);
            s.getAsyncRemote().sendText(jsonPayload);
        } else {
            System.out.println("No active WebSocket session for player " + playerId + ". Payload not delivered: " + jsonPayload);
        }
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
        if (s == null) return "";
        return s.replace("\"", "\\\"");
    }

    // Mini-Parser für sehr simples JSON:  "key": 123
    private Long extractLong(String json, String key) {
        String pattern = "\"" + key + "\":";
        int idx = json.indexOf(pattern);
        if (idx < 0) {
            throw new IllegalArgumentException("Missing field: " + key);
        }

        int start = idx + pattern.length();
        while (start < json.length() && Character.isWhitespace(json.charAt(start))) {
            start++;
        }

        int end = start;
        while (end < json.length()
                && json.charAt(end) != ','
                && json.charAt(end) != '}') {
            end++;
        }

        String numberPart = json.substring(start, end).trim();
        return Long.valueOf(numberPart);
    }

    private double extractDouble(String json, String key) {
        String pattern = "\"" + key + "\":";
        int idx = json.indexOf(pattern);
        if (idx < 0) throw new IllegalArgumentException("Missing field: " + key);

        int start = idx + pattern.length();
        while (start < json.length() && Character.isWhitespace(json.charAt(start))) start++;

        int end = start;
        while (end < json.length()
                && json.charAt(end) != ','
                && json.charAt(end) != '}') {
            end++;
        }

        String numberPart = json.substring(start, end).trim();
        return Double.parseDouble(numberPart);
    }


    // Mini-Parser für: "key": "value"
    private String extractString(String json, String key) {
        String pattern = "\"" + key + "\":";
        int idx = json.indexOf(pattern);
        if (idx < 0) throw new IllegalArgumentException("Missing field: " + key);
        int start = json.indexOf('"', idx + pattern.length());
        int end   = json.indexOf('"', start + 1);
        return json.substring(start + 1, end);
    }

    private static final Map<Long, Map<Long, Integer>> BATTLE_ANSWERS = new ConcurrentHashMap<>();

    private void handleBattleAnswer(String message, Long playerId) {
        Long battleId    = extractLong(message, "battleId");
        int answerIndex  = extractInt(message, "answerIndex");

        if (playerId == null) {
            System.out.println("battle-answer ohne playerId, ignoriere");
            return;
        }

        Battle battle = battleService.findById(battleId);
        if (battle == null) {
            System.out.println("battle-answer: battle " + battleId + " nicht gefunden");
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
        if ("DONE".equalsIgnoreCase(battle.getStatus())) {
            System.out.println("battle-answer: Battle " + battleId + " schon DONE, ignoriere");
            return;
        }

        boolean isCorrect = (answerIndex == correctIndex);

        // Antwort speichern (falls du später Stats brauchst)
        BATTLE_ANSWERS
                .computeIfAbsent(battleId, id -> new ConcurrentHashMap<>())
                .put(playerId, answerIndex);

        System.out.printf("battle-answer: battle %d, player %d -> %d (korrekt=%s)%n",
                battleId, playerId, answerIndex, isCorrect);

        if (isCorrect) {
            // Der erste, der korrekt ist, gewinnt sofort
            String winnerName = battle.getFromPlayer().getId().equals(playerId)
                    ? battle.getFromPlayer().getName()
                    : battle.getToPlayer().getName();

            endKnowledgeBattleWithWinner(battle, winnerName);

            // Antworten für dieses Battle zurücksetzen
            BATTLE_ANSWERS.remove(battleId);
        } else {
            // Falsche Antwort: einfach ignorieren, anderer kann noch gewinnen
            // (Optional: Du könntest hier Feedback "falsch" schicken)
            System.out.println("battle-answer: falsche Antwort, Battle läuft weiter");
        }
    }



    private int extractInt(String json, String key) {
        return extractLong(json, key).intValue();
    }

    private boolean isKnowledgeBattle(Battle battle) {
        if (battle == null || battle.getChallenge() == null || battle.getChallenge().getChallengeCategory() == null) {
            return false;
        }
        String name = battle.getChallenge().getChallengeCategory().getName();
        return "Wissen".equalsIgnoreCase(name);
    }

    private void endKnowledgeBattleWithWinner(Battle battle, String winnerName) {
        Long battleId = battle.getId();
        System.out.printf("endKnowledgeBattleWithWinner: battle %d, winner=%s%n", battleId, winnerName);

        try {
            String pendingPayload = """
        {
          "type": "battle-pending",
          "battleId": %d
        }
        """.formatted(battleId);

            sendToPlayer(battle.getFromPlayer().getId(), pendingPayload);
            sendToPlayer(battle.getToPlayer().getId(), pendingPayload);

            // Nur noch computeAndBroadcastResult → dort wird finalizeResult EINMAL aufgerufen
            List<String> votes = List.of(winnerName);
            computeAndBroadcastResult(battle, votes);

        } catch (Exception e) {
            e.printStackTrace();
            System.out.println("Fehler beim finalisieren von Wissen-Battle " + battleId + ": " + e.getMessage());
        }
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
        "choices": ["%s","%s","%s","%s"],
        "correctIndex": %d
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
                escapeJson(challenge.getOptionD()),
                challenge.getCorrectIndex()
        );

        sendToPlayer(battle.getFromPlayer().getId(), json);
        sendToPlayer(battle.getToPlayer().getId(), json);
    }

    private void handleCheckinDone(Battle battle, Long senderId) {
        if (senderId == null) return;

        Long fromId = battle.getFromPlayer().getId();
        Long toId   = battle.getToPlayer().getId();

        String winnerName;
        if (Objects.equals(senderId, fromId)) {
            winnerName = battle.getFromPlayer().getName();
        } else if (Objects.equals(senderId, toId)) {
            winnerName = battle.getToPlayer().getName();
        } else {
            System.out.printf("CHECKIN_DONE: sender %d gehört nicht zu Battle %d%n",
                    senderId, battle.getId());
            return;
        }

        // pending-Overlay wie bei anderen
        String pendingPayload = """
    {
      "type": "battle-pending",
      "battleId": %d
    }
    """.formatted(battle.getId());

        sendToPlayer(fromId, pendingPayload);
        sendToPlayer(toId, pendingPayload);

        // Punkte berechnen + Ergebnis rausschicken (wie Wissen)
        List<String> votes = List.of(winnerName);
        computeAndBroadcastResult(battle, votes);
    }

    private void handleSprintResult(String message, Long playerId) {
        Long battleId = extractLong(message, "battleId");
        double distance = extractDouble(message, "distance");

        System.out.println("➡️ sprint-result parsed: battleId=" + battleId + ", distance=" + distance);
        if (playerId == null) {
            System.out.println("sprint-result ohne playerId, ignoriere");
            return;
        }

        Battle battle = battleService.findById(battleId);
        if (battle == null) {
            System.out.println("sprint-result: battle " + battleId + " nicht gefunden");
            return;
        }

        SPRINT_RESULTS
                .computeIfAbsent(battleId, id -> new ConcurrentHashMap<>())
                .put(playerId, distance);

        Map<Long, Double> map = SPRINT_RESULTS.get(battleId);
        Long fromId = battle.getFromPlayer().getId();
        Long toId   = battle.getToPlayer().getId();

        // Wenn der andere Spieler noch nichts geschickt hat → 0 m annehmen
        double distFrom = map.getOrDefault(fromId, 0.0);
        double distTo   = map.getOrDefault(toId,   0.0);

        String winnerName;
        if (distFrom > distTo) {
            winnerName = battle.getFromPlayer().getName();
        } else if (distTo > distFrom) {
            winnerName = battle.getToPlayer().getName();
        } else {
            winnerName = "Niemand"; // Unentschieden
        }

        String pendingPayload = """
    {
      "type": "battle-pending",
      "battleId": %d
    }
    """.formatted(battleId);

        sendToPlayer(fromId, pendingPayload);
        sendToPlayer(toId,   pendingPayload);

        System.out.println("✅ Sprint ausgewertet, from=" + distFrom + ", to=" + distTo
                + ", winner=" + winnerName);

        computeAndBroadcastResult(battle, List.of(winnerName));
        SPRINT_RESULTS.remove(battleId);
    }

    private void handleLoudnessResult(String message, Long playerId) {
        Long battleId = extractLong(message, "battleId");
        double loudness = extractDouble(message, "loudness");

        System.out.println("➡️ loudness-result parsed: battleId=" + battleId + ", loudness=" + loudness);
        if (playerId == null) {
            System.out.println("loudness-result ohne playerId, ignoriere");
            return;
        }

        Battle battle = battleService.findById(battleId);
        if (battle == null) {
            System.out.println("loudness-result: battle " + battleId + " nicht gefunden");
            return;
        }

        LOUDNESS_RESULTS
                .computeIfAbsent(battleId, id -> new ConcurrentHashMap<>())
                .put(playerId, loudness);

        Map<Long, Double> map = LOUDNESS_RESULTS.get(battleId);
        Long fromId = battle.getFromPlayer().getId();
        Long toId   = battle.getToPlayer().getId();

        // Wenn der andere Spieler noch nichts geschickt hat → -60 dB annehmen (Minimum)
        double loudnessFrom = map.getOrDefault(fromId, -60.0);
        double loudnessTo   = map.getOrDefault(toId,   -60.0);

        String winnerName;
        if (loudnessFrom > loudnessTo) {
            winnerName = battle.getFromPlayer().getName();
        } else if (loudnessTo > loudnessFrom) {
            winnerName = battle.getToPlayer().getName();
        } else {
            winnerName = "Niemand"; // Unentschieden
        }

        String pendingPayload = """
    {
      "type": "battle-pending",
      "battleId": %d
    }
    """.formatted(battleId);

        sendToPlayer(fromId, pendingPayload);
        sendToPlayer(toId,   pendingPayload);

        System.out.println("✅ Loudness ausgewertet, from=" + loudnessFrom + " dB, to=" + loudnessTo + " dB"
                + ", winner=" + winnerName);

        computeAndBroadcastResult(battle, List.of(winnerName));
        LOUDNESS_RESULTS.remove(battleId);
    }



}
