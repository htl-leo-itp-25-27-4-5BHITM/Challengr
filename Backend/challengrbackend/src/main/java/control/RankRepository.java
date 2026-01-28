package control;

import entity.Challenges;
import entity.Rank;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;

import java.util.List;

@ApplicationScoped
public class RankRepository {
    @Inject
    EntityManager em;

    public List<Rank> getAllRanks() {
        var query = em.createQuery("SELECT c FROM Rank c", Rank.class);
        return query.getResultList();
    }

}
