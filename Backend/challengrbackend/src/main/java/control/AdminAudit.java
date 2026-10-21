package control;

import entity.AdminAuditEntry;
import io.quarkus.security.identity.SecurityIdentity;
import jakarta.enterprise.context.RequestScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import org.eclipse.microprofile.jwt.JsonWebToken;

import java.util.List;

/** Schreibt ins Admin-Protokoll – wer es war, kommt aus dem Login. */
@RequestScoped
public class AdminAudit {

    @Inject
    EntityManager em;

    @Inject
    SecurityIdentity identity;

    public String adminId() {
        return identity == null || identity.isAnonymous() ? "?" : identity.getPrincipal().getName();
    }

    /** Lesbarer Name: Keycloak-Benutzername, sonst die ID. */
    public String adminName() {
        if (identity != null && identity.getPrincipal() instanceof JsonWebToken jwt) {
            Object name = jwt.getClaim("preferred_username");
            if (name != null) return name.toString();
        }
        return adminId();
    }

    /** Muss innerhalb einer Transaktion laufen. */
    public void log(String action, String playerId, String playerName, Object oldValue, Object newValue, String reason) {
        em.persist(new AdminAuditEntry(adminId(), adminName(), action, playerId, playerName,
                oldValue == null ? null : oldValue.toString(), newValue == null ? null : newValue.toString(), reason));
    }

    public List<AdminAuditEntry> recent(String playerId, int limit) {
        var q = playerId == null
                ? em.createQuery("SELECT a FROM AdminAuditEntry a ORDER BY a.createdAt DESC", AdminAuditEntry.class)
                : em.createQuery("SELECT a FROM AdminAuditEntry a WHERE a.playerId = :p ORDER BY a.createdAt DESC", AdminAuditEntry.class)
                        .setParameter("p", playerId);
        return q.setMaxResults(Math.max(1, Math.min(limit, 500))).getResultList();
    }
}
