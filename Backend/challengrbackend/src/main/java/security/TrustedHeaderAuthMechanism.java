package security;

import io.quarkus.security.identity.IdentityProviderManager;
import io.quarkus.security.identity.SecurityIdentity;
import io.quarkus.security.identity.request.AuthenticationRequest;
import io.quarkus.security.runtime.QuarkusPrincipal;
import io.quarkus.security.runtime.QuarkusSecurityIdentity;
import io.quarkus.vertx.http.runtime.security.ChallengeData;
import io.quarkus.vertx.http.runtime.security.HttpAuthenticationMechanism;
import io.smallrye.mutiny.Uni;
import io.vertx.ext.web.RoutingContext;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.util.Arrays;
import java.util.Set;

/**
 * NUR Dev, Tests und Test-Harness: vertraut dem Header {@code X-Player-Id} (und {@code X-Player-Roles}),
 * weil dort kein Keycloak läuft. In Prod ist das aus ({@code challengr.auth.trust-player-header=false},
 * zusätzlich von {@link control.ProdSecretsGuard} geprüft) – dort zählt nur das Keycloak-Token.
 */
@ApplicationScoped
public class TrustedHeaderAuthMechanism implements HttpAuthenticationMechanism {

    public static final String PLAYER_HEADER = "X-Player-Id";
    public static final String ROLES_HEADER = "X-Player-Roles";

    @ConfigProperty(name = "challengr.auth.trust-player-header", defaultValue = "false")
    boolean enabled;

    @Override
    public Uni<SecurityIdentity> authenticate(RoutingContext context, IdentityProviderManager identityProviderManager) {
        if (!enabled) return Uni.createFrom().optional(java.util.Optional.empty());
        String playerId = context.request().getHeader(PLAYER_HEADER);
        if ((playerId == null || playerId.isBlank()) && context.request().path().startsWith("/ws/")) {
            // Browser-/Node-WebSockets können keine Header setzen (Test-Gegner im Harness)
            playerId = context.request().getParam("playerId");
        }
        if (playerId == null || playerId.isBlank()) return Uni.createFrom().optional(java.util.Optional.empty());
        QuarkusSecurityIdentity.Builder identity = QuarkusSecurityIdentity.builder()
                .setPrincipal(new QuarkusPrincipal(playerId.trim()));
        String roles = context.request().getHeader(ROLES_HEADER);
        if (roles != null) {
            Arrays.stream(roles.split(",")).map(String::trim).filter(r -> !r.isEmpty()).forEach(identity::addRole);
        }
        return Uni.createFrom().item(identity.build());
    }

    @Override
    public Uni<ChallengeData> getChallenge(RoutingContext context) {
        return Uni.createFrom().item(new ChallengeData(401, null, null));
    }

    @Override
    public Set<Class<? extends AuthenticationRequest>> getCredentialTypes() {
        return Set.of();
    }
}
