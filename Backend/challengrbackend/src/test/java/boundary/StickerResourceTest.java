package boundary;

import control.StickerCatalog;
import control.StickerRepository;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.path.json.JsonPath;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.Random;

import static org.junit.jupiter.api.Assertions.*;

/** Sticker sammeln: Start-Paket, Geschenke, Sieg-Sticker, Tagesaufgabe, Shop-Paket, Album-Stufen. */
@QuarkusTest
class StickerResourceTest {

    @Inject
    StickerRepository stickers;

    /** Würfelt immer dasselbe – für die Sieg-Chance */
    private static Random always(int value) {
        return new Random() {
            @Override
            public int nextInt(int bound) {
                return value;
            }
        };
    }

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

    private static int countOf(List<Map<String, Object>> album, String sticker) {
        return album.stream().filter(s -> sticker.equals(s.get("stickerId")))
                .mapToInt(s -> ((Number) s.get("count")).intValue()).findFirst().orElse(0);
    }

    private int coins(String player) {
        return Login.as(player).when().get("/api/stickers/album").then().statusCode(200).extract().path("coins");
    }

    private io.restassured.response.ValidatableResponse gift(String from, String to, String sticker) {
        String body = sticker == null
                ? "{\"fromPlayerId\":\"" + from + "\",\"toPlayerId\":\"" + to + "\"}"
                : "{\"fromPlayerId\":\"" + from + "\",\"toPlayerId\":\"" + to + "\",\"stickerId\":\"" + sticker + "\"}";
        return Login.as(from).contentType("application/json").body(body).when().post("/api/friends/gifts").then();
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

    @Test
    void albumStagesMatchTheCatalog() {
        StickerCatalog.Stage last = StickerCatalog.STAGES.get(StickerCatalog.STAGES.size() - 1);
        assertEquals(StickerCatalog.FALLBACK.size(), last.found(), "letzte Stufe = volles Album");
        assertTrue(last.goldFrame());
    }

    @Test
    void stickerPackCostsCoins() {
        String p = newPlayer("stk-pack");
        int before = coins(p);
        JsonPath pack = Login.as(p).when().post("/api/stickers/pack").then().statusCode(200).extract().jsonPath();
        assertEquals(StickerCatalog.PACK_SIZE, pack.getList("stickers").size());
        assertEquals(before - StickerCatalog.PACK_PRICE, pack.getInt("coins"));
        assertEquals(StickerCatalog.STARTER_PACK + StickerCatalog.PACK_SIZE, sum(album(p), "total"));

        while (coins(p) >= StickerCatalog.PACK_PRICE) Login.as(p).when().post("/api/stickers/pack").then().statusCode(200);
        Login.as(p).when().post("/api/stickers/pack").then().statusCode(409); // pleite
    }

    @Test
    void albumStagesPayOnceAndTheFullAlbumGivesTheGoldFrame() {
        String p = newPlayer("stk-album");
        album(p);
        Login.as(p).when().post("/api/stickers/album/5/claim").then().statusCode(409); // erst 3 gefunden
        Login.as(p).when().post("/api/stickers/album/7/claim").then().statusCode(404);

        StickerCatalog.FALLBACK.keySet().forEach(id -> stickers.grant(p, id));
        int before = coins(p);
        JsonPath album = Login.as(p).when().post("/api/stickers/album/5/claim").then().statusCode(200).extract().jsonPath();
        assertEquals(StickerCatalog.FALLBACK.size(), album.getInt("found"));
        assertEquals(before + 50, album.getInt("coins"));
        assertEquals(StickerCatalog.PACK_PRICE, album.getInt("packPrice"));
        assertTrue(album.getBoolean("stages[0].claimed"));
        assertFalse(album.getBoolean("stages[1].claimed"));
        Login.as(p).when().post("/api/stickers/album/5/claim").then().statusCode(409); // nur einmal

        assertFalse(Login.as(p).when().get("/api/players/" + p).then().statusCode(200).extract().<Boolean>path("goldFrame"));
        Login.as(p).when().post("/api/stickers/album/20/claim").then().statusCode(200);
        assertTrue(Login.as(p).when().get("/api/players/" + p).then().statusCode(200).extract().<Boolean>path("goldFrame"));
    }

    @Test
    void ownStickersCanBeGiftedToFriends() {
        String a = newPlayer("stk-ga");
        String b = newPlayer("stk-gb");
        befriend(a, b);
        stickers.grant(a, "aura");
        int auraBefore = countOf(album(a), "aura");

        gift(a, b, null).statusCode(200);
        gift(a, b, "aura").statusCode(200); // zählt nicht als Tages-Geschenk
        assertEquals(auraBefore - 1, countOf(album(a), "aura"));
        gift(a, b, "gibtsnicht").statusCode(400);
        while (countOf(album(a), "aura") > 0) gift(a, b, "aura").statusCode(200);
        gift(a, b, "aura").statusCode(409); // keiner mehr da

        List<Map<String, Object>> incoming = Login.as(b).when().get("/api/friends/gifts/incoming?playerId=" + b)
                .then().statusCode(200).extract().jsonPath().getList("$");
        incoming.forEach(g -> assertNull(g.get("stickerId"), "Inhalt bleibt bis zum Öffnen geheim"));
        Map<String, Object> chosen = incoming.stream().filter(g -> Boolean.TRUE.equals(g.get("fromCollection"))).findFirst().orElseThrow();

        JsonPath opened = Login.as(b).contentType("application/json")
                .when().post("/api/friends/gifts/" + chosen.get("id") + "/claim?playerId=" + b).then().statusCode(200).extract().jsonPath();
        assertEquals("aura", opened.getString("stickerId"));
        assertTrue(opened.getBoolean("fromCollection"));
        assertTrue(countOf(album(b), "aura") >= 1);
    }

    @Test
    void friendsMissingAStickerAreListed() {
        String a = newPlayer("stk-ma");
        String b = newPlayer("stk-mb");
        befriend(a, b);
        stickers.grant(b, "mvp");
        String missingAtB = StickerCatalog.FALLBACK.keySet().stream()
                .filter(id -> album(b).stream().noneMatch(s -> id.equals(s.get("stickerId")))).findFirst().orElseThrow();

        List<String> missingMvp = Login.as(a).when().get("/api/stickers/mvp/friends-missing").then().statusCode(200).extract().jsonPath().getList("$");
        assertFalse(missingMvp.contains(b));
        List<String> missingOther = Login.as(a).when().get("/api/stickers/" + missingAtB + "/friends-missing").then().statusCode(200).extract().jsonPath().getList("$");
        assertEquals(List.of(b), missingOther);
        Login.as(a).when().get("/api/stickers/gibtsnicht/friends-missing").then().statusCode(404);
    }

    @Test
    void theDailyVisitTaskGivesASticker() {
        String p = newPlayer("stk-visit");
        Login.as(p).when().get("/api/quests").then().statusCode(200);
        JsonPath board = Login.as(p).when().post("/api/quests/daily/VISIT/claim").then().statusCode(200).extract().jsonPath();
        assertTrue(board.getBoolean("daily[0].sticker"));
        assertFalse(board.getBoolean("daily[1].sticker"));
        String sticker = board.getString("claimedSticker");
        assertTrue(StickerCatalog.FALLBACK.containsKey(sticker), "Sticker: " + sticker);
        assertEquals(StickerCatalog.STARTER_PACK + 1, sum(album(p), "total"));
    }

    @Test
    void winStickersAreCappedPerDayAndBattle() {
        String p = newPlayer("stk-win");
        assertNull(stickers.maybeWinDrop(p, 1, always(StickerCatalog.WIN_DROP_PERCENT))); // Pech
        assertNotNull(stickers.maybeWinDrop(p, 1, always(0)));
        assertNull(stickers.maybeWinDrop(p, 1, always(0)), "pro Battle nur einmal");
        for (int i = 2; i <= StickerCatalog.WIN_DROPS_PER_DAY; i++) assertNotNull(stickers.maybeWinDrop(p, i, always(0)));
        assertNull(stickers.maybeWinDrop(p, 99, always(0)), "Tages-Grenze");
        assertEquals(StickerCatalog.STARTER_PACK + StickerCatalog.WIN_DROPS_PER_DAY, sum(album(p), "total"));
    }
}
