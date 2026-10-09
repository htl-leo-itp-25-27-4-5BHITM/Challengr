package boundary;

import entity.Player;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.ws.rs.Priorities;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.container.ContainerRequestFilter;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.Provider;
import org.jboss.logging.Logger;

import java.time.Instant;
import java.util.Map;

/**
 * Blocks banned players from using the API.
 *
 * Der Spieler kommt aus dem Login (Keycloak-Token bzw. in Dev/Test aus dem X-Player-Id-Login),
 * nicht mehr aus einem frei setzbaren Header. Ist er gesperrt, gibt es 403 mit JSON-Body.
 */
@Provider
@Priority(Priorities.AUTHORIZATION)
@ApplicationScoped
public class BanEnforcementFilter implements ContainerRequestFilter {

    private static final Logger LOG = Logger.getLogger(BanEnforcementFilter.class);

    @Inject
    EntityManager em;

    @Inject
    io.quarkus.security.identity.SecurityIdentity identity;

    @Override
    public void filter(ContainerRequestContext ctx) {
        String path = ctx.getUriInfo().getPath();
        if (path == null) {
            return;
        }

        if (LOG.isDebugEnabled()) {
            LOG.debugf("BanEnforcementFilter path=%s", path);
        }

        // Only enforce on API routes.
        if (!path.startsWith("api/")) {
            return;
        }

        // Allow-list: endpoints used before the app knows the player id.
        if (path.startsWith("api/admin/")) {
            return;
        }
        // No further allow-list here. We only enforce when a client presents a player id.

        String playerId = identity == null || identity.isAnonymous() ? null : trimToNull(identity.getPrincipal().getName());
        if (playerId == null) {
            return; // no user context presented
        }

        Player p = em.find(Player.class, playerId);
        if (p == null) {
            return;
        }
        if (p.getBanUntil() == null) {
            return;
        }

        Instant now = Instant.now();
        if (p.getBanUntil().isAfter(now)) {
            ctx.abortWith(Response.status(Response.Status.FORBIDDEN)
                    .type(MediaType.APPLICATION_JSON)
                    .entity(Map.of(
                            "error", "banned",
                            "message", "Player is banned",
                            "banUntil", p.getBanUntil(),
                            "banReason", p.getBanReason()
                    ))
                    .build());
        }
    }

    private static String trimToNull(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }
}
