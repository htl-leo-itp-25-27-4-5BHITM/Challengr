package control;

import entity.PushToken;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.PrivateKey;
import java.security.Signature;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;

/**
 * Schickt Push-Benachrichtigungen über Apples Push-Dienst (APNs, HTTP/2).
 * Ohne Schlüssel (Secret challengr-apns) ist Push einfach aus – das Spiel läuft ganz normal.
 */
@ApplicationScoped
public class ApnsClient {

    /** Antwort von Apple: Statuscode + Grund (z. B. "BadDeviceToken") */
    public record Result(int status, String reason) {
        /** Token taugt nicht mehr (App gelöscht, falsche Umgebung) → vergessen */
        public boolean tokenGone() {
            return status == 410 || (status == 400 && ("BadDeviceToken".equals(reason) || "DeviceTokenNotForTopic".equals(reason)));
        }
    }

    @ConfigProperty(name = "challengr.apns.key-id")
    Optional<String> keyId;

    @ConfigProperty(name = "challengr.apns.team-id")
    Optional<String> teamId;

    @ConfigProperty(name = "challengr.apns.private-key")
    Optional<String> privateKeyPem;

    private final HttpClient http = HttpClient.newBuilder()
            .version(HttpClient.Version.HTTP_2).connectTimeout(Duration.ofSeconds(10)).build();
    private String cachedToken;
    private Instant tokenValidUntil = Instant.EPOCH;

    public boolean isConfigured() {
        return keyId.filter(s -> !s.isBlank()).isPresent() && teamId.filter(s -> !s.isBlank()).isPresent()
                && privateKeyPem.filter(s -> !s.isBlank()).isPresent();
    }

    public CompletableFuture<Result> send(PushToken device, String payloadJson) {
        if (!isConfigured()) return CompletableFuture.completedFuture(new Result(0, "nicht eingerichtet"));
        String host = device.isSandbox() ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
        HttpRequest request = HttpRequest.newBuilder(URI.create(host + "/3/device/" + device.getToken()))
                .timeout(Duration.ofSeconds(10))
                .header("authorization", "bearer " + token())
                .header("apns-topic", device.getTopic())
                .header("apns-push-type", "alert")
                .header("apns-priority", "10")
                // Herausforderungen sind nach einer Minute vorbei – später nicht mehr zustellen
                .header("apns-expiration", String.valueOf(Instant.now().plus(Duration.ofMinutes(10)).getEpochSecond()))
                .POST(HttpRequest.BodyPublishers.ofString(payloadJson, StandardCharsets.UTF_8))
                .build();
        return http.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenApply(r -> new Result(r.statusCode(), reason(r.body())))
                .exceptionally(e -> new Result(-1, e.getMessage()));
    }

    private synchronized String token() {
        Instant now = Instant.now();
        if (cachedToken == null || now.isAfter(tokenValidUntil)) {
            cachedToken = jwt(teamId.orElseThrow(), keyId.orElseThrow(),
                    AppStoreConnectClient.parsePrivateKey(privateKeyPem.orElseThrow()), now);
            tokenValidUntil = now.plus(Duration.ofMinutes(40));   // Apple: höchstens 1 h, frühestens alle 20 min neu
        }
        return cachedToken;
    }

    /** APNs-Token: ES256, kid = Key ID, iss = Team-ID */
    public static String jwt(String teamId, String keyId, PrivateKey key, Instant now) {
        Base64.Encoder b64 = Base64.getUrlEncoder().withoutPadding();
        String header = "{\"alg\":\"ES256\",\"kid\":\"" + keyId + "\"}";
        String payload = "{\"iss\":\"" + teamId + "\",\"iat\":" + now.getEpochSecond() + "}";
        String signingInput = b64.encodeToString(header.getBytes(StandardCharsets.UTF_8)) + "."
                + b64.encodeToString(payload.getBytes(StandardCharsets.UTF_8));
        try {
            Signature signature = Signature.getInstance("SHA256withECDSAinP1363Format");
            signature.initSign(key);
            signature.update(signingInput.getBytes(StandardCharsets.UTF_8));
            return signingInput + "." + b64.encodeToString(signature.sign());
        } catch (Exception e) {
            throw new IllegalStateException("Push-Token konnte nicht signiert werden", e);
        }
    }

    private static String reason(String body) {
        var m = java.util.regex.Pattern.compile("\"reason\"\\s*:\\s*\"([^\"]+)\"").matcher(body == null ? "" : body);
        return m.find() ? m.group(1) : null;
    }
}
