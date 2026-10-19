package control;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;

/**
 * Lesezugriff auf die App Store Connect API (TestFlight-Feedback). Anmeldung mit einem API-Schlüssel
 * (Issuer-ID, Key-ID, .p8-Datei) aus dem Kubernetes-Secret {@code challengr-asc}. Ohne Schlüssel ist
 * die Funktion einfach aus ({@link #isConfigured()}).
 */
@ApplicationScoped
public class AppStoreConnectClient {

    static final String BASE = "https://api.appstoreconnect.apple.com";

    /** Apple-Fehler mit HTTP-Status (z. B. 401 = Schlüssel falsch, 403 = Rolle fehlt). */
    public static class AscException extends RuntimeException {
        public final int status;

        public AscException(int status, String message) {
            super(message);
            this.status = status;
        }
    }

    @ConfigProperty(name = "challengr.asc.issuer-id")
    Optional<String> issuerId;

    @ConfigProperty(name = "challengr.asc.key-id")
    Optional<String> keyId;

    @ConfigProperty(name = "challengr.asc.private-key")
    Optional<String> privateKeyPem;

    @ConfigProperty(name = "challengr.asc.bundle-id", defaultValue = "com.challengrapp.challengr")
    String bundleId;

    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    private final ObjectMapper json = new ObjectMapper();
    private String cachedToken;
    private Instant tokenValidUntil = Instant.EPOCH;
    private String cachedAppId;

    public boolean isConfigured() {
        return issuerId.filter(s -> !s.isBlank()).isPresent()
                && keyId.filter(s -> !s.isBlank()).isPresent()
                && privateKeyPem.filter(s -> !s.isBlank()).isPresent();
    }

    /** Interne App-ID in App Store Connect (aus der Bundle-ID). */
    public synchronized String appId() {
        if (cachedAppId == null) {
            JsonNode apps = get("/v1/apps?filter[bundleId]=" + URLEncoder.encode(bundleId, StandardCharsets.UTF_8)
                    + "&fields[apps]=bundleId");
            JsonNode first = apps.path("data").path(0);
            if (first.isMissingNode()) {
                throw new AscException(404, "App mit Bundle-ID " + bundleId + " nicht gefunden");
            }
            cachedAppId = first.path("id").asText();
        }
        return cachedAppId;
    }

    /** GET auf einen API-Pfad ("/v1/…") oder eine vollständige URL (Seiten-Links von Apple). */
    public JsonNode get(String pathOrUrl) {
        if (!isConfigured()) throw new AscException(503, "App Store Connect ist nicht eingerichtet");
        String url = pathOrUrl.startsWith("https://") ? pathOrUrl : BASE + pathOrUrl;
        if (!url.startsWith(BASE + "/")) throw new IllegalArgumentException("Nur App Store Connect erlaubt");
        HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(20))
                .header("Authorization", "Bearer " + token())
                .header("Accept", "application/json")
                .GET().build();
        try {
            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() >= 300) {
                throw new AscException(response.statusCode(), errorText(response.body()));
            }
            return json.readTree(response.body());
        } catch (IOException e) {
            throw new AscException(502, "App Store Connect nicht erreichbar: " + e.getMessage());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new AscException(502, "Abgebrochen");
        }
    }

    private String errorText(String body) {
        try {
            JsonNode error = json.readTree(body).path("errors").path(0);
            String detail = error.path("detail").asText(error.path("title").asText(""));
            return detail.isBlank() ? "Fehler von App Store Connect" : detail;
        } catch (IOException e) {
            return "Fehler von App Store Connect";
        }
    }

    private synchronized String token() {
        Instant now = Instant.now();
        if (cachedToken == null || now.isAfter(tokenValidUntil)) {
            cachedToken = jwt(issuerId.orElseThrow(), keyId.orElseThrow(), parsePrivateKey(privateKeyPem.orElseThrow()), now);
            tokenValidUntil = now.plus(Duration.ofMinutes(15));   // Apple erlaubt max. 20 min
        }
        return cachedToken;
    }

    /** Signiertes Token nach Apple-Vorgabe: ES256, Audience "appstoreconnect-v1", höchstens 20 Minuten gültig. */
    static String jwt(String issuer, String keyId, PrivateKey key, Instant now) {
        Base64.Encoder b64 = Base64.getUrlEncoder().withoutPadding();
        String header = "{\"alg\":\"ES256\",\"kid\":\"" + keyId + "\",\"typ\":\"JWT\"}";
        String payload = "{\"iss\":\"" + issuer + "\",\"iat\":" + now.getEpochSecond()
                + ",\"exp\":" + now.plus(Duration.ofMinutes(19)).getEpochSecond() + ",\"aud\":\"appstoreconnect-v1\"}";
        String signingInput = b64.encodeToString(header.getBytes(StandardCharsets.UTF_8)) + "."
                + b64.encodeToString(payload.getBytes(StandardCharsets.UTF_8));
        try {
            // JWT braucht die Signatur als R||S (64 Byte), nicht im DER-Format
            Signature signature = Signature.getInstance("SHA256withECDSAinP1363Format");
            signature.initSign(key);
            signature.update(signingInput.getBytes(StandardCharsets.UTF_8));
            return signingInput + "." + b64.encodeToString(signature.sign());
        } catch (Exception e) {
            throw new IllegalStateException("Token konnte nicht signiert werden", e);
        }
    }

    /** Inhalt der .p8-Datei (PEM, PKCS#8) – auch mit "\n" statt echten Zeilenumbrüchen. */
    static PrivateKey parsePrivateKey(String pem) {
        String base64 = pem.replace("\\n", "\n")
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replaceAll("\\s", "");
        try {
            return KeyFactory.getInstance("EC").generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(base64)));
        } catch (Exception e) {
            throw new IllegalStateException("Der App-Store-Connect-Schlüssel (.p8) ist ungültig", e);
        }
    }
}
