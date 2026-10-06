package control;

import entity.HotspotCheckin;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;

import java.time.LocalDate;

@ApplicationScoped
public class HotspotRepository {

    @Inject
    EntityManager em;

    public long countOnDay(String hotspotId, LocalDate day) {
        return em.createQuery("SELECT COUNT(c) FROM HotspotCheckin c WHERE c.hotspotId = :h AND c.day = :d", Long.class)
                .setParameter("h", hotspotId).setParameter("d", day).getSingleResult();
    }

    public boolean hasCheckedIn(String playerId, String hotspotId, LocalDate day) {
        return em.createQuery("SELECT COUNT(c) FROM HotspotCheckin c WHERE c.playerId = :p AND c.hotspotId = :h AND c.day = :d", Long.class)
                .setParameter("p", playerId).setParameter("h", hotspotId).setParameter("d", day)
                .getSingleResult() > 0;
    }

    public void persist(HotspotCheckin checkin) {
        em.persist(checkin);
    }
}
