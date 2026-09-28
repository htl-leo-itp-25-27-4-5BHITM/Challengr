package boundary;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.websocket.ClientEndpoint;
import jakarta.websocket.ContainerProvider;
import jakarta.websocket.OnMessage;
import jakarta.websocket.Session;

import java.net.URI;
import java.util.List;
import java.util.concurrent.LinkedBlockingDeque;
import java.util.concurrent.TimeUnit;

/** Einfacher WebSocket-Client für Tests: sammelt alle empfangenen Nachrichten. */
@ClientEndpoint
public class WsTestClient {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    final String playerId;
    final LinkedBlockingDeque<JsonNode> messages = new LinkedBlockingDeque<>();
    Session session;

    public WsTestClient() {
        this(null);
    }

    WsTestClient(String playerId) {
        this.playerId = playerId;
    }

    static WsTestClient connect(URI wsHttpUri, String playerId) throws Exception {
        WsTestClient client = new WsTestClient(playerId);
        URI uri = URI.create(wsHttpUri.toString().replaceFirst("^http", "ws") + "?playerId=" + playerId);
        client.session = ContainerProvider.getWebSocketContainer().connectToServer(client, uri);
        return client;
    }

    @OnMessage
    public void onMessage(String text) throws Exception {
        messages.add(MAPPER.readTree(text));
    }

    void send(String json) throws Exception {
        session.getBasicRemote().sendText(json);
    }

    void close() throws Exception {
        if (session != null && session.isOpen()) session.close();
    }

    /** Wartet auf die nächste Nachricht dieses Typs (andere werden verworfen). */
    JsonNode await(String type, long seconds) throws InterruptedException {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(seconds);
        while (System.nanoTime() < deadline) {
            JsonNode m = messages.poll(50, TimeUnit.MILLISECONDS);
            if (m != null && type.equals(m.path("type").asText())) return m;
        }
        return null;
    }

    /** Wartet auf "battle-updated" mit genau diesem Status. */
    JsonNode awaitStatus(String status, long seconds) throws InterruptedException {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(seconds);
        while (System.nanoTime() < deadline) {
            JsonNode m = messages.poll(50, TimeUnit.MILLISECONDS);
            if (m != null && "battle-updated".equals(m.path("type").asText())
                    && status.equals(m.path("status").asText())) {
                return m;
            }
        }
        return null;
    }

    List<JsonNode> all(String type) {
        return messages.stream().filter(m -> type.equals(m.path("type").asText())).toList();
    }
}
