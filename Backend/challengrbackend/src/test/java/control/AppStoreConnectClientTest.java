package control;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.security.spec.ECGenParameterSpec;
import java.time.Instant;
import java.util.Base64;

import static org.junit.jupiter.api.Assertions.*;

/** Token für App Store Connect: richtig aufgebaut und mit dem Schlüssel überprüfbar. */
class AppStoreConnectClientTest {

    private KeyPair keyPair() throws Exception {
        KeyPairGenerator g = KeyPairGenerator.getInstance("EC");
        g.initialize(new ECGenParameterSpec("secp256r1"));
        return g.generateKeyPair();
    }

    @Test
    void tokenIsAValidEs256JwtForAppStoreConnect() throws Exception {
        KeyPair kp = keyPair();
        Instant now = Instant.ofEpochSecond(1_800_000_000L);
        String jwt = AppStoreConnectClient.jwt("issuer-123", "KEY42", kp.getPrivate(), now);
        String[] parts = jwt.split("\\.");
        assertEquals(3, parts.length);

        String header = new String(Base64.getUrlDecoder().decode(parts[0]), StandardCharsets.UTF_8);
        String payload = new String(Base64.getUrlDecoder().decode(parts[1]), StandardCharsets.UTF_8);
        assertTrue(header.contains("\"alg\":\"ES256\"") && header.contains("\"kid\":\"KEY42\""));
        assertTrue(payload.contains("\"iss\":\"issuer-123\"") && payload.contains("\"aud\":\"appstoreconnect-v1\""));
        assertTrue(payload.contains("\"exp\":" + (now.getEpochSecond() + 19 * 60)), "max. 20 Minuten gültig");

        byte[] sig = Base64.getUrlDecoder().decode(parts[2]);
        assertEquals(64, sig.length, "R||S-Format wie JWT es verlangt");
        Signature verify = Signature.getInstance("SHA256withECDSAinP1363Format");
        verify.initVerify(kp.getPublic());
        verify.update((parts[0] + "." + parts[1]).getBytes(StandardCharsets.UTF_8));
        assertTrue(verify.verify(sig));
    }

    @Test
    void p8KeyIsReadWithRealOrEscapedLineBreaks() throws Exception {
        KeyPair kp = keyPair();
        String b64 = Base64.getMimeEncoder(64, "\n".getBytes()).encodeToString(kp.getPrivate().getEncoded());
        String pem = "-----BEGIN PRIVATE KEY-----\n" + b64 + "\n-----END PRIVATE KEY-----\n";
        assertArrayEquals(kp.getPrivate().getEncoded(), AppStoreConnectClient.parsePrivateKey(pem).getEncoded());
        assertArrayEquals(kp.getPrivate().getEncoded(), AppStoreConnectClient.parsePrivateKey(pem.replace("\n", "\\n")).getEncoded());
        assertThrows(IllegalStateException.class, () -> AppStoreConnectClient.parsePrivateKey("kein schlüssel"));
    }
}
