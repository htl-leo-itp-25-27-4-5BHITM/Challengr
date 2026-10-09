package control;

import io.quarkus.runtime.Startup;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.util.Map;
import java.util.Set;

/**
 * A6: Prod startet nur mit echten Secrets. Die Werte werden über @ConfigProperty eingelesen –
 * fehlt eine Umgebungsvariable, bricht Quarkus schon bei der Konfigurationsprüfung ab
 * (vor Datenbank und Keycloak). Bekannte Standard-Passwörter werden ebenfalls abgelehnt.
 * In Dev/Test stehen harmlose Platzhalter in application.properties und die Prüfung ist aus.
 */
@Startup
@ApplicationScoped
public class ProdSecretsGuard {

    static final Set<String> WEAK = Set.of("secret", "postgres", "admin", "password", "changeme", "sa", "");

    @ConfigProperty(name = "challengr.guard.enabled", defaultValue = "false")
    boolean enabled;

    @ConfigProperty(name = "challengr.guard.keycloak-client-secret")
    String keycloakClientSecret;

    @ConfigProperty(name = "challengr.guard.datasource-password")
    String datasourcePassword;

    @ConfigProperty(name = "challengr.auth.trust-player-header", defaultValue = "false")
    boolean trustPlayerHeader;

    @PostConstruct
    void check() {
        if (!enabled) return;
        if (trustPlayerHeader) {
            // Der X-Player-Id-Login ist nur für Dev/Test – in Prod könnte sich sonst jeder als jeder ausgeben
            throw new IllegalStateException("challengr.auth.trust-player-header darf in Prod nicht aktiv sein");
        }
        check(Map.of("KEYCLOAK_CLIENT_SECRET", keycloakClientSecret,
                      "QUARKUS_DATASOURCE_PASSWORD", datasourcePassword));
    }

    static void check(Map<String, String> secrets) {
        secrets.forEach((name, value) -> {
            if (value == null || WEAK.contains(value.trim().toLowerCase())) {
                throw new IllegalStateException(name + " ist nicht gesetzt oder ein Standardwert – Prod startet so nicht");
            }
        });
    }
}
