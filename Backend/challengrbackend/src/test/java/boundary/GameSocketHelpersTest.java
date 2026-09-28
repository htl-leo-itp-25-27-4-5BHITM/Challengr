package boundary;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/** Reine Hilfsfunktionen von GameSocket – ohne Server. */
class GameSocketHelpersTest {

    private final ObjectMapper mapper = new ObjectMapper();

    private JsonNode json(String s) throws Exception {
        return mapper.readTree(s);
    }

    @Test
    void escapeProducesValidJson() throws Exception {
        String tricky = "Er sagte \"Hallo\"\nC:\\Pfad\tTab \u0001 Ende 🎉";
        JsonNode parsed = json("{\"t\":\"" + GameSocket.escapeJsonStatic(tricky) + "\"}");
        assertEquals(tricky, parsed.get("t").asText());
    }

    @Test
    void escapeNullIsEmpty() {
        assertEquals("", GameSocket.escapeJsonStatic(null));
    }

    @Test
    void numbersMayArriveAsNumberOrString() throws Exception {
        assertEquals(42L, GameSocket.requireLong(json("{\"id\":42}"), "id"));
        assertEquals(42L, GameSocket.requireLong(json("{\"id\":\"42\"}"), "id"));
        assertEquals(1.5, GameSocket.requireDouble(json("{\"d\":1.5}"), "d"), 0.0001);
        assertEquals(1.5, GameSocket.requireDouble(json("{\"d\":\"1.5\"}"), "d"), 0.0001);
    }

    @Test
    void missingOrInvalidFieldsThrow() throws Exception {
        assertThrows(IllegalArgumentException.class, () -> GameSocket.requireLong(json("{}"), "id"));
        assertThrows(IllegalArgumentException.class, () -> GameSocket.requireLong(json("{\"id\":null}"), "id"));
        assertThrows(IllegalArgumentException.class, () -> GameSocket.requireLong(json("{\"id\":\"abc\"}"), "id"));
        assertThrows(IllegalArgumentException.class, () -> GameSocket.requireText(json("{}"), "status"));
    }

    @Test
    void playerIdsMayBeNumbersFromOldClients() throws Exception {
        assertEquals("3", GameSocket.playerIdField(json("{\"fromId\":3}"), "fromId"));
        assertEquals("abc-123", GameSocket.playerIdField(json("{\"fromId\":\"abc-123\"}"), "fromId"));
        assertNull(GameSocket.playerIdField(json("{}"), "fromId"));
    }

    @Test
    void positionPayloadHasNoCoordinates() throws Exception {
        JsonNode payload = json(GameSocket.buildPlayerPositionPayload("p-1"));
        assertEquals("player-position-updated", payload.get("type").asText());
        assertEquals("p-1", payload.get("playerId").asText());
        assertFalse(payload.has("latitude"));
        assertFalse(payload.has("longitude"));
    }
}
