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
import java.util.Map;
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

    @Inject
    BattleService battleService;

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
        // NICHT @Blocking
        CompletableFuture.runAsync(() -> handleMessage(message, session));
    }

    private void handleMessage(String message, Session session) {
        try {
            if (message.contains("\"type\":\"create-battle\"")) {
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

                sendToPlayer(toId, payload);

            } else if (message.contains("\"type\":\"update-battle-status\"")) {
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
        } catch (Exception e) {
            e.printStackTrace();
            session.getAsyncRemote().sendText("""
            { "type": "error", "message": "%s" }
            """.formatted(e.getMessage()));
        }
    }


    // --- Hilfsfunktionen ---

    private void sendToPlayer(Long playerId, String jsonPayload) {
        Session s = SESSIONS.get(playerId);
        if (s != null && s.isOpen()) {
            s.getAsyncRemote().sendText(jsonPayload);
        }
    }

    // Mini-Parser für sehr simples JSON:  "key": 123
    private Long extractLong(String json, String key) {
        String pattern = "\"" + key + "\":";
        int idx = json.indexOf(pattern);
        if (idx < 0) {
            throw new IllegalArgumentException("Missing field: " + key);
        }

        // ab dem Doppelpunkt weiter
        int start = idx + pattern.length();

        // alle Leerzeichen überspringen
        while (start < json.length() && Character.isWhitespace(json.charAt(start))) {
            start++;
        }

        // bis zum nächsten Komma oder schließender Klammer lesen
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
