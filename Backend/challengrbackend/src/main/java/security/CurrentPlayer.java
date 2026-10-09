package security;

import io.quarkus.security.identity.SecurityIdentity;
import jakarta.enterprise.context.RequestScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotAuthorizedException;

/**
 * Wer gerade fragt – immer aus dem Login (Keycloak-Token, Claim {@code sub} = Spieler-ID),
 * nie aus Pfad, Query oder Body.
 */
@RequestScoped
public class CurrentPlayer {

    public static final String ADMIN_ROLE = "admin";

    @Inject
    SecurityIdentity identity;

    public String id() {
        if (identity == null || identity.isAnonymous()) {
            throw new NotAuthorizedException("Bearer");
        }
        return identity.getPrincipal().getName();
    }

    public boolean isAdmin() {
        return identity != null && !identity.isAnonymous() && identity.hasRole(ADMIN_ROLE);
    }

    /** Schreibende Aktionen nur auf das eigene Konto (Admins dürfen alles) – sonst 403. */
    public String requireSelf(String playerId) {
        String me = id();
        if (!me.equals(playerId) && !isAdmin()) {
            throw new ForbiddenException("Nur für das eigene Konto erlaubt");
        }
        return me;
    }

    /** Fremde Spieler-ID oder ich selbst? */
    public boolean isSelf(String playerId) {
        return identity != null && !identity.isAnonymous() && identity.getPrincipal().getName().equals(playerId);
    }
}
