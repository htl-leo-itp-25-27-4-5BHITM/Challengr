package control;

import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

/**
 * B1 (Apple-Regel 5.1.1(v)): Konto in der App löschen.
 * Persönliche Daten werden gelöscht; vergangene Battles bleiben für die Statistik der Gegner,
 * zeigen aber nur noch den anonymen Platzhalter "Gelöschter Spieler".
 */
@ApplicationScoped
public class AccountDeletionService {

    private static final Logger LOG = Logger.getLogger(AccountDeletionService.class);

    /** Platzhalter für Battles gelöschter Spieler (ohne Standort, unsichtbar, nie einloggbar). */
    public static final String DELETED_PLAYER_ID = "deleted-player";
    public static final String DELETED_PLAYER_NAME = "Gelöschter Spieler";

    @Inject
    EntityManager em;

    @Inject
    BanService banService;

    /** Prod: das Keycloak-Konto MUSS mitgelöscht werden, sonst bricht das Löschen ab. */
    @ConfigProperty(name = "challengr.account-deletion.require-keycloak", defaultValue = "false")
    boolean requireKeycloak;

    /** Keycloak-Konto (falls konfiguriert) und alle Daten des Spielers löschen. */
    public void deleteAccount(String playerId) {
        if (banService.keycloakAdminConfigured()) {
            banService.deleteKeycloakUser(playerId);
        } else if (requireKeycloak) {
            throw new IllegalStateException("Keycloak-Admin-API nicht konfiguriert – Konto kann nicht gelöscht werden");
        } else {
            LOG.warnf("Keycloak-Admin-API nicht konfiguriert – nur die Spieldaten von %s werden gelöscht (Dev/Test)", playerId);
        }
        deleteData(playerId);
    }

    @Transactional
    public void deleteData(String playerId) {
        Player player = em.find(Player.class, playerId);
        if (player == null) return;
        Player placeholder = placeholder();

        em.createQuery("UPDATE Battle b SET b.fromPlayer = :p WHERE b.fromPlayer = :old")
                .setParameter("p", placeholder).setParameter("old", player).executeUpdate();
        em.createQuery("UPDATE Battle b SET b.toPlayer = :p WHERE b.toPlayer = :old")
                .setParameter("p", placeholder).setParameter("old", player).executeUpdate();
        em.createQuery("UPDATE Battle b SET b.winner = :p WHERE b.winner = :old")
                .setParameter("p", placeholder).setParameter("old", player).executeUpdate();

        em.createQuery("DELETE FROM Friendship f WHERE f.playerAId = :id OR f.playerBId = :id")
                .setParameter("id", playerId).executeUpdate();
        em.createQuery("DELETE FROM FriendRequest r WHERE r.fromPlayerId = :id OR r.toPlayerId = :id")
                .setParameter("id", playerId).executeUpdate();
        em.createQuery("DELETE FROM FriendGift g WHERE g.fromPlayerId = :id OR g.toPlayerId = :id")
                .setParameter("id", playerId).executeUpdate();
        em.createQuery("DELETE FROM HotspotCheckin c WHERE c.playerId = :id")
                .setParameter("id", playerId).executeUpdate();
        em.createQuery("DELETE FROM PlayerItem i WHERE i.playerId = :id")
                .setParameter("id", playerId).executeUpdate();

        em.remove(em.contains(player) ? player : em.merge(player));
        LOG.infof("Konto %s gelöscht", playerId);
    }

    private Player placeholder() {
        Player p = em.find(Player.class, DELETED_PLAYER_ID);
        if (p == null) {
            p = new Player(DELETED_PLAYER_NAME, 0, 0);
            p.setId(DELETED_PLAYER_ID);
            p.setInvisible(true);
            em.persist(p);
        }
        return p;
    }
}
