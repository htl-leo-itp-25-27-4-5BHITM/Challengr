package control;

import entity.Player;
import io.quarkus.logging.Log;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.rest.client.inject.RestClient;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

@ApplicationScoped
public class BanService {

    @ConfigProperty(name = "challengr.keycloak.admin.realm", defaultValue = "challengr")
    String realm;

    @ConfigProperty(name = "challengr.keycloak.admin.client-id")
    java.util.Optional<String> clientId;

    @ConfigProperty(name = "challengr.keycloak.admin.client-secret")
    java.util.Optional<String> clientSecret;

    @Inject
    PlayerRepository playerRepository;

    @Inject
    @RestClient
    KeycloakAdminTokenClient tokenClient;

    @Inject
    @RestClient
    KeycloakAdminUserClient userClient;

    @Transactional
    public Player banPlayer(String playerId, Duration duration, String reason) {
        if (playerId == null || playerId.isBlank()) throw new IllegalArgumentException("playerId must not be blank");
        if (duration == null || duration.isNegative() || duration.isZero()) {
            throw new IllegalArgumentException("duration must be > 0");
        }

        Player p = playerRepository.findById(playerId);
        if (p == null) throw new IllegalArgumentException("player not found");

        Instant until = Instant.now().plus(duration);
        p.setBanUntil(until);
        p.setBanReason(reason);

        setKeycloakEnabled(playerId, false);

        return p;
    }

    @Transactional
    public Player unbanPlayer(String playerId) {
        if (playerId == null || playerId.isBlank()) throw new IllegalArgumentException("playerId must not be blank");

        Player p = playerRepository.findById(playerId);
        if (p == null) throw new IllegalArgumentException("player not found");

        p.setBanUntil(null);
        p.setBanReason(null);

        setKeycloakEnabled(playerId, true);

        return p;
    }

    @Transactional
    public int unbanExpired() {
        Instant now = Instant.now();
        List<Player> expired = playerRepository.findBannedExpired(now);
        int count = 0;
        for (Player p : expired) {
            try {
                p.setBanUntil(null);
                p.setBanReason(null);
                setKeycloakEnabled(p.getId(), true);
                count++;
            } catch (Exception e) {
                Log.warnf(e, "Failed to unban player %s", p.getId());
            }
        }
        return count;
    }

    private void setKeycloakEnabled(String keycloakUserId, boolean enabled) {
        String cid = clientId.orElse(null);
        String cs = clientSecret.orElse(null);

        if (cid == null || cid.isBlank() || cs == null || cs.isBlank()) {
            // Fail fast: without this we can't guarantee bans.
            throw new IllegalStateException("Keycloak admin client credentials are not configured");
        }

    var token = tokenClient.token(realm, "client_credentials", cid, cs);
        String auth = "Bearer " + token.accessToken();

        var existing = userClient.getUser(auth, realm, keycloakUserId);
        if (existing != null && existing.enabled() != null && existing.enabled() == enabled) {
            return; // no-op
        }

        userClient.updateUser(auth, realm, keycloakUserId,
                new KeycloakAdminUserClient.UserRepresentation(existing == null ? keycloakUserId : existing.id(),
                        existing == null ? null : existing.username(),
                        enabled,
                        existing == null ? null : existing.emailVerified()));
    }
}
