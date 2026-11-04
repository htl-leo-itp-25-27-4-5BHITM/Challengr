package boundary;

import control.StickerCatalog;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.path.json.JsonPath;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.Random;

import static org.junit.jupiter.api.Assertions.*;

/** Sticker sammeln: Start-Paket, Geschenke mit Zufalls-Sticker, eins pro Freund und Tag. */
@QuarkusTest
class StickerResourceTest {

    private String newPlayer(String prefix) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + id + "\",\"latitude\":46.9,\"longitude\":14.9}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    private void befriend(String a, String b) {
        long requestId = ((Number) Login.as(a).contentType("application/json")
                .body("{\"fromPlayerId\":\"" + a + "\",\"toPlayerId\":\"" + b + "\"}")
                .when().post("/api/friends/requests").then().statusCode(200).extract().path("id")).longValue();
        Login.as(b).contentType("application/json").when().post("/api/friends/requests/" + requestId + "/accept").then().statusCode(200);
    }

    private List<Map<String, Object>> album(String player) {
        return Login.as(player).when().get("/api/stickers").then().statusCode(200).extract().jsonPath().getList("$");
    }

    private static int sum(List<Map<String, Object>> album, String key) {
        return album.stream().mapToInt(s -> ((Number) s.get(key)).intValue()).sum();
    }

    @Test
    void newPlayersGetAStarterPackOnce() {
        String p = newPlayer("stk-start");
        List<Map<String, Object>> first = album(p);
        assertEquals(StickerCatalog.STARTER_PACK, sum(first, "count"));
        assertEquals(StickerCatalog.STARTER_PACK, sum(first, "total"));
        first.forEach(s -> assertTrue(StickerCatalog.FALLBACK.containsKey((String) s.get("stickerId"))));
        assertEquals(first, album(p), "kein zweites Start-Paket");
    }

    @Test
    void openingAGiftAddsOneRandomSticker() {
        String a = newPlayer("stk-a");
        String b = newPlayer("stk-b");
        befriend(a, b);

        Login.as(a).contentType("application/json").body("{\"fromPlayerId\":\"" + a + "\",\"toPlayerId\":\"" + b + "\"}")
                .when().post("/api/friends/gifts").then().statusCode(200);
        Login.as(a).contentType("application/json").body("{\"fromPlayerId\":\"" + a + "\",\"toPlayerId\":\"" + b + "\"}")
                .when().post("/api/friends/gifts").then().statusCode(429); // eins pro Freund und Tag

        long giftId = ((Number) Login.as(b).when().get("/api/friends/gifts/incoming?playerId=" + b)
                .then().statusCode(200).extract().path("[0].id")).longValue();
        JsonPath opened = Login.as(b).contentType("application/json")
                .when().post("/api/friends/gifts/" + giftId + "/claim?playerId=" + b).then().statusCode(200).extract().jsonPath();
        String sticker = opened.getString("stickerId");
        assertTrue(StickerCatalog.FALLBACK.containsKey(sticker), "Geschenk enthält einen Sticker: " + sticker);

        List<Map<String, Object>> collection = album(b);
        assertEquals(StickerCatalog.STARTER_PACK + 1, sum(collection, "total"), "Start-Paket + Geschenk");
        assertTrue(collection.stream().anyMatch(s -> sticker.equals(s.get("stickerId"))));

        // Nochmal öffnen bringt nichts
        Login.as(b).contentType("application/json").when().post("/api/friends/gifts/" + giftId + "/claim?playerId=" + b).then().statusCode(200);
        assertEquals(StickerCatalog.STARTER_PACK + 1, sum(album(b), "total"));
    }

    @Test
    void animatedStickersAreRarer() {
        Random rnd = new Random(42);
        int animated = 0, n = 20_000;
        for (int i = 0; i < n; i++) if (StickerCatalog.ANIMATED.contains(StickerCatalog.random(rnd))) animated++;
        // 6 bewegte mit Gewicht 1, 14 normale mit Gewicht 3 → 6/48 = 12,5 %
        assertEquals(0.125, animated / (double) n, 0.015);
    }
}
