package boundary;

import entity.Battle;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
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

    // Votes pro Battle: battleId -> Liste der Gewinner-Namen
    private static final Map<Long, List<String>> BATTLE_VOTES = new ConcurrentHashMap<>();

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
                session.close();
            } catch (IOException ignored) {}
            return;
        }
        Long playerId = Long.valueOf(params.get(0));
        SESSIONS.put(playerId, session);
        System.out.println("WebSocket open for player " + playerId);
    }

    @OnClose
    public void onClose(Session session) {
        // Session aus Map entfernen
        SESSIONS.entrySet().removeIf(e -> e.getValue().getId().equals(session.getId()));
        System.out.println("WebSocket closed: " + session.getId());
    }

    @OnMessage
    public void onMessage(String message, Session session) {
        CompletableFuture.runAsync(() -> handleMessage(message, session));
    }

    // ---------------------------------------------------------
    // Message Handling
    // ---------------------------------------------------------

    private void handleMessage(String message, Session session) {
        try {
            if (message.contains("\"type\":\"create-battle\"")) {
                handleCreateBattle(message);

            } else if (message.contains("\"type\":\"update-battle-status\"")) {
                handleUpdateBattleStatus(message);

            } else if (message.contains("\"type\":\"battle-vote\"")) {
                handleBattleVote(message);

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

        Battle battle = battleService.createRequestedBattle(fromId, toId, challengeId);

        String payload = """
            {
              "type": "battle-requested",
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

        // nur an den Herausgeforderten schicken
        sendToPlayer(toId, payload);
    }

    // ---------------- update-battle-status -------------------

    private void handleUpdateBattleStatus(String message) {
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

        // Sobald 2 Votes da sind, Ergebnis berechnen
        if (votes.size() >= 2) {
            computeAndBroadcastResult(battleId, votes);
            BATTLE_VOTES.remove(battleId);
        }
    }

    private void computeAndBroadcastResult(Long battleId, List<String> votes) {
        // Simple Logik:
        // Wenn beide das Gleiche wählen => dieser Name gewinnt,
        // sonst gewinnt der erste Vote, der zweite ist Verlierer.
        String winnerName = votes.get(0);
        String loserName  = "Unbekannt";

        if (votes.size() >= 2) {
            String second = votes.get(1);
            if (!second.equals(winnerName)) {
                loserName = second;
            }
        }

        if ("Unbekannt".equals(loserName)) {
            loserName = "Gegner";
        }

        int winnerDelta = 20;
        int loserDelta  = -10;

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
              "trashTalk": "GG!"
            }
            """.formatted(
                battleId,
                escapeJson(winnerName),
                winnerDelta,
                escapeJson(loserName),
                loserDelta
        );

        // Ergebnis an alle verbundenen Spieler schicken (einfacher fürs Testen)
        SESSIONS.values().forEach(s -> {
            if (s.isOpen()) {
                s.getAsyncRemote().sendText(payload);
            }
        });

        System.out.println("Sent battle-result for battle " + battleId + ": " + payload);
    }

    // ---------------------------------------------------------
    // Hilfsfunktionen
    // ---------------------------------------------------------

    private void sendToPlayer(Long playerId, String jsonPayload) {
        Session s = SESSIONS.get(playerId);
        if (s != null && s.isOpen()) {
            s.getAsyncRemote().sendText(jsonPayload);
        }
    }

    private void sendError(Session session, String msg) {
        if (session != null && session.isOpen()) {
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

    // Mini-Parser für: "key": "value"
    private String extractString(String json, String key) {
        String pattern = "\"" + key + "\":";
        int idx = json.indexOf(pattern);
        if (idx < 0) throw new IllegalArgumentException("Missing field: " + key);
        int start = json.indexOf('"', idx + pattern.length());
        int end   = json.indexOf('"', start + 1);
        return json.substring(start + 1, end);
    }
}
