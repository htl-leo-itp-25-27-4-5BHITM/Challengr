package control;

import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/** A6: schwache oder fehlende Secrets verhindern den Prod-Start. */
class ProdSecretsGuardTest {

    @Test
    void rejectsDefaultsAndBlanks() {
        for (String weak : new String[]{"secret", "postgres", "admin", " ", "Admin"}) {
            assertThrows(IllegalStateException.class, () -> ProdSecretsGuard.check(Map.of("X", weak)), weak);
        }
    }

    @Test
    void acceptsRealSecrets() {
        assertDoesNotThrow(() -> ProdSecretsGuard.check(Map.of("X", "k9R2-qL7xV8m-wP3t")));
    }
}
