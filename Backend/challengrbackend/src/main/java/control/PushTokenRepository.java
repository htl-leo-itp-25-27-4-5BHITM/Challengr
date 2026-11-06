package control;

import entity.PushToken;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.time.Instant;
import java.util.List;

/** Geräte-Tokens für Push-Benachrichtigungen. */
@ApplicationScoped
public class PushTokenRepository {

    @Inject
    EntityManager em;

    /** Anmelden oder aktualisieren; meldet sich ein anderer Spieler am selben Gerät an, wandert das Token mit. */
    @Transactional
    public void register(String playerId, String token, String topic, boolean sandbox) {
        PushToken t = find(token);
        if (t == null) {
            em.persist(new PushToken(playerId, token, topic, sandbox));
            return;
        }
        t.setPlayerId(playerId);
        t.setTopic(topic);
        t.setSandbox(sandbox);
        t.setUpdatedAt(Instant.now());
    }

    @Transactional
    public List<PushToken> forPlayer(String playerId) {
        return em.createQuery("SELECT t FROM PushToken t WHERE t.playerId = :p", PushToken.class)
                .setParameter("p", playerId).getResultList();
    }

    /** Abmelden (nur das eigene Gerät) */
    @Transactional
    public boolean remove(String playerId, String token) {
        return em.createQuery("DELETE FROM PushToken t WHERE t.token = :t AND t.playerId = :p")
                .setParameter("t", token).setParameter("p", playerId).executeUpdate() > 0;
    }

    /** Apple meldet das Token als ungültig (App gelöscht, Mitteilungen aus) */
    @Transactional
    public void forget(String token) {
        em.createQuery("DELETE FROM PushToken t WHERE t.token = :t").setParameter("t", token).executeUpdate();
    }

    private PushToken find(String token) {
        return em.createQuery("SELECT t FROM PushToken t WHERE t.token = :t", PushToken.class)
                .setParameter("t", token).getResultStream().findFirst().orElse(null);
    }
}
