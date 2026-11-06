package control;

import boundary.GameSocket;
import entity.Player;
import entity.PushToken;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.context.control.ActivateRequestContext;
import jakarta.inject.Inject;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Push-Benachrichtigungen für Spieler, die die App gerade nicht offen haben
 * (Herausforderung, Geschenk, Freundschaftsanfrage). Wer online ist, sieht es ohnehin in der App.
 * Läuft auch aus dem WebSocket heraus (dort ohne Request-Kontext); ein Fehler hier hält das Spiel nie auf.
 */
@ApplicationScoped
@ActivateRequestContext
public class PushService {

    public enum Kind { CHALLENGE, GIFT, FRIEND_REQUEST, FRIEND_ACCEPTED }

    /** Gleiche Art vom gleichen Absender höchstens so oft – gegen Spam */
    static final Duration SAME_PUSH_GAP = Duration.ofSeconds(30);

    @Inject
    PushTokenRepository tokens;

    @Inject
    ApnsClient apns;

    @Inject
    PlayerRepository players;

    private final Map<String, Instant> lastSent = new ConcurrentHashMap<>();

    public void challenge(String toId, String fromId, BattleMode mode) {
        String what = switch (mode) {
            case RANKED_KNOWLEDGE -> "Quiz-Show in der Liga";
            case RANKED_REALLIFE -> "Real-Life-Challenge in der Liga";
            case FRIENDLY -> "Friendly";
        };
        notifyOffline(toId, fromId, Kind.CHALLENGE, "⚔️ " + name(fromId) + " fordert dich heraus!",
                what + " – schnell öffnen, die Anfrage läuft nach einer Minute ab.");
    }

    public void gift(String toId, String fromId) {
        notifyOffline(toId, fromId, Kind.GIFT, "🎁 Geschenk von " + name(fromId), "Mach es auf – drin steckt ein Sticker.");
    }

    public void friendRequest(String toId, String fromId) {
        notifyOffline(toId, fromId, Kind.FRIEND_REQUEST, "👋 Freundschaftsanfrage", name(fromId) + " möchte mit dir befreundet sein.");
    }

    public void friendAccepted(String toId, String fromId) {
        notifyOffline(toId, fromId, Kind.FRIEND_ACCEPTED, "🤝 Neuer Freund", name(fromId) + " hat deine Anfrage angenommen.");
    }

    /** true = verschickt (an alle Geräte des Spielers) */
    boolean notifyOffline(String toId, String fromId, Kind kind, String title, String body) {
        try {
            return send(toId, fromId, kind, title, body);
        } catch (Exception e) {
            System.out.println("Push fehlgeschlagen: " + e.getMessage());
            return false;
        }
    }

    private boolean send(String toId, String fromId, Kind kind, String title, String body) {
        if (toId == null || GameSocket.isOnline(toId)) return false;
        Instant now = Instant.now();
        String key = toId + "|" + fromId + "|" + kind;
        Instant last = lastSent.get(key);
        if (last != null && last.plus(SAME_PUSH_GAP).isAfter(now)) return false;
        var devices = tokens.forPlayer(toId);
        if (devices.isEmpty()) return false;
        lastSent.put(key, now);
        String payload = payload(kind, title, body, fromId);
        for (PushToken device : devices) {
            apns.send(device, payload).thenAccept(r -> {
                if (r.tokenGone()) tokens.forget(device.getToken());
                else if (r.status() != 200) System.out.println("Push nicht zugestellt: " + r.status() + " " + r.reason());
            });
        }
        return true;
    }

    static String payload(Kind kind, String title, String body, String fromId) {
        return """
            {"aps":{"alert":{"title":"%s","body":"%s"},"sound":"default","thread-id":"%s"},"kind":"%s","from":"%s"}
            """.formatted(json(title), json(body), kind.name().toLowerCase(), kind.name(), json(fromId)).strip();
    }

    private String name(String playerId) {
        Player p = playerId == null ? null : players.findById(playerId);
        return p == null || p.getName() == null ? "Jemand" : p.getName();
    }

    private static String json(String s) {
        return s == null ? "" : s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ");
    }
}
