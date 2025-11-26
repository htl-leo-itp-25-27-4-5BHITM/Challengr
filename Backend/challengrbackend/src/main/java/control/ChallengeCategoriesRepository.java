package control;

import entity.Challenges;
import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;

import java.util.List;

@ApplicationScoped
public class ChallengeRepository {

    @Inject
    EntityManager em;

    public List<Challenges> getAllChallenges() {
        var query = em.createQuery("SELECT c FROM Challenges c", Challenges.class);

        return query.getResultList();
    }

}
