package boundary;

import control.ApnsClient;
import control.PushTokenRepository;
import entity.PushToken;
import io.quarkus.test.common.http.TestHTTPResource;
import io.quarkus.test.junit.QuarkusMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.security.spec.ECGenParameterSpec;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CopyOnWriteArrayList;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.*;

/** Push-Benachrichtigungen: nur an Spieler ohne offene App, mit Spam-Bremse; ungültige Tokens fliegen raus. */
@QuarkusTest
class PushTest {

    /** Statt Apple: merkt sich, was verschickt worden wäre */
    static class FakeApns extends ApnsClient {
        final List<String[]> sent = new CopyOnWriteArrayList<>();
        volatile int status = 200;

        @Override
        public boolean isConfigured() { return true; }

        @Override
        public CompletableFuture<Result> send(PushToken device, String payloadJson) {
            sent.add(new String[]{device.getToken(), payloadJson});
            return CompletableFuture.completedFuture(new Result(status, status == 410 ? "Unregistered" : null));
        }

        List<String> payloadsTo(String token) {
            return sent.stream().filter(s -> s[0].equals(token)).map(s -> s[1]).toList();
        }
    }

    @TestHTTPResource("/ws/game")
    URI wsUri;

    @Inject
    PushTokenRepository tokens;

    @Inject
    control.StickerRepository stickers;

    FakeApns apns;

    @BeforeEach
    void fake() {
        apns = new FakeApns();
        QuarkusMock.installMockForType(apns, ApnsClient.class);
    }

    private String newPlayer(String prefix, String name) {
        String id = prefix + "-" + System.nanoTime();
        Login.as(id).contentType("application/json")
                .body("{\"id\":\"" + id + "\",\"name\":\"" + name + "\",\"latitude\":46.9,\"longitude\":14.9}")
                .when().post("/api/players").then().statusCode(200);
        return id;
    }

    private String registerDevice(String player) {
        String token = Long.toHexString(System.nanoTime()) + "a".repeat(48);
        Login.as(player).contentType("application/json")
                .body("{\"token\":\"" + token + "\",\"topic\":\"com.challengrapp.challengr\",\"sandbox\":false}")
                .when().post("/api/push/token").then().statusCode(204);
        return token;
    }

    private long friendRequest(String from, String to) {
        return ((Number) Login.as(from).contentType("application/json")
                .body("{\"fromPlayerId\":\"" + from + "\",\"toPlayerId\":\"" + to + "\"}")
                .when().post("/api/friends/requests").then().statusCode(200).extract().path("id")).longValue();
    }

    @Test
    void registeringNeedsLoginAndAValidToken() {
        String p = newPlayer("push-reg", "Reg");
        given().contentType("application/json").body("{\"token\":\"abcd1234abcd1234abcd1234abcd1234\",\"topic\":\"a.b\"}")
                .when().post("/api/push/token").then().statusCode(401);
        Login.as(p).contentType("application/json").body("{\"token\":\"kein-hex!\",\"topic\":\"com.challengrapp.challengr\"}")
                .when().post("/api/push/token").then().statusCode(400);
        Login.as(p).contentType("application/json").body("{\"token\":\"abcd1234abcd1234abcd1234abcd1234\",\"topic\":\"<script>\"}")
                .when().post("/api/push/token").then().statusCode(400);
    }

    @Test
    void offlinePlayersGetPushedForFriendRequestsAndAccepts() {
        String a = newPlayer("push-a", "Mia");
        String b = newPlayer("push-b", "Basti");
        String tokenA = registerDevice(a);
        String tokenB = registerDevice(b);

        long id = friendRequest(a, b);
        List<String> toB = apns.payloadsTo(tokenB);
        assertEquals(1, toB.size());
        assertTrue(toB.get(0).contains("FRIEND_REQUEST") && toB.get(0).contains("Mia"), toB.get(0));

        Login.as(b).contentType("application/json").when().post("/api/friends/requests/" + id + "/accept").then().statusCode(200);
        assertTrue(apns.payloadsTo(tokenA).stream().anyMatch(p -> p.contains("FRIEND_ACCEPTED") && p.contains("Basti")));
    }

    @Test
    void playersWithTheAppOpenGetNoPush() throws Exception {
        String a = newPlayer("push-on-a", "A");
        String b = newPlayer("push-on-b", "B");
        String tokenB = registerDevice(b);
        WsTestClient online = WsTestClient.connect(wsUri, b);
        try {
            Thread.sleep(300);
            friendRequest(a, b);
            assertTrue(apns.payloadsTo(tokenB).isEmpty(), "App ist offen – die zeigt es selbst");
        } finally {
            online.close();
        }
    }

    @Test
    void challengesToOfflinePlayersArePushedOnce() throws Exception {
        String a = newPlayer("push-ch-a", "Herausforderer");
        String b = newPlayer("push-ch-b", "B");
        String tokenB = registerDevice(b);
        WsTestClient challenger = WsTestClient.connect(wsUri, a);
        try {
            challenger.send("{\"type\":\"create-battle\",\"toId\":\"" + b + "\",\"challengeId\":1}");
            assertNotNull(challenger.await("battle-created", 5));
            Thread.sleep(200);
            List<String> toB = apns.payloadsTo(tokenB);
            assertEquals(1, toB.size());
            assertTrue(toB.get(0).contains("CHALLENGE") && toB.get(0).contains("Herausforderer"), toB.get(0));
        } finally {
            challenger.close();
        }
    }

    @Test
    void sameKindFromTheSameSenderIsThrottled() {
        String a = newPlayer("push-sp-a", "A");
        String b = newPlayer("push-sp-b", "B");
        String tokenB = registerDevice(b);
        long id = friendRequest(a, b);
        Login.as(b).contentType("application/json").when().post("/api/friends/requests/" + id + "/accept").then().statusCode(200);
        stickers.grant(a, "aura");
        apns.sent.clear();
        String gift = "{\"fromPlayerId\":\"" + a + "\",\"toPlayerId\":\"" + b + "\"}";
        Login.as(a).contentType("application/json").body(gift).when().post("/api/friends/gifts").then().statusCode(200);
        Login.as(a).contentType("application/json").body(gift.replace("}", ",\"stickerId\":\"aura\"}"))
                .when().post("/api/friends/gifts").then().statusCode(200);
        assertEquals(1, apns.payloadsTo(tokenB).size(), "zweites Geschenk innerhalb von 30 s ohne Push");
        assertTrue(apns.payloadsTo(tokenB).get(0).contains("GIFT"));
    }

    @Test
    void tokensAppleRejectsAreForgotten() throws Exception {
        String a = newPlayer("push-gone-a", "A");
        String b = newPlayer("push-gone-b", "B");
        registerDevice(b);
        apns.status = 410;
        friendRequest(a, b);
        Thread.sleep(200);
        assertTrue(tokens.forPlayer(b).isEmpty());
    }

    @Test
    void onlyTheOwnerCanUnregisterADevice() {
        String a = newPlayer("push-un-a", "A");
        String b = newPlayer("push-un-b", "B");
        String tokenB = registerDevice(b);
        Login.as(a).when().delete("/api/push/token/" + tokenB).then().statusCode(204);
        assertEquals(1, tokens.forPlayer(b).size(), "fremdes Gerät bleibt");
        Login.as(b).when().delete("/api/push/token/" + tokenB).then().statusCode(204);
        assertTrue(tokens.forPlayer(b).isEmpty());
    }

    @Test
    void jwtIsSignedForApple() throws Exception {
        var gen = KeyPairGenerator.getInstance("EC");
        gen.initialize(new ECGenParameterSpec("secp256r1"));
        var keys = gen.generateKeyPair();
        String jwt = ApnsClient.jwt("TEAM123456", "KEY1234567", keys.getPrivate(), Instant.ofEpochSecond(1_700_000_000));
        String[] parts = jwt.split("\\.");
        assertEquals(3, parts.length);
        String header = new String(Base64.getUrlDecoder().decode(parts[0]), StandardCharsets.UTF_8);
        String claims = new String(Base64.getUrlDecoder().decode(parts[1]), StandardCharsets.UTF_8);
        assertEquals("{\"alg\":\"ES256\",\"kid\":\"KEY1234567\"}", header);
        assertEquals("{\"iss\":\"TEAM123456\",\"iat\":1700000000}", claims);
        Signature verify = Signature.getInstance("SHA256withECDSAinP1363Format");
        verify.initVerify(keys.getPublic());
        verify.update((parts[0] + "." + parts[1]).getBytes(StandardCharsets.UTF_8));
        assertTrue(verify.verify(Base64.getUrlDecoder().decode(parts[2])));
    }
}
