package control;

import entity.Challenges;
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

    public List<Challenges> findChallengesByKat(String kategorie) {
        var query = em.createQuery(
                "SELECT c FROM Challenges c WHERE c.challengeCategory.name = :categorie",
                Challenges.class
        );
        query.setParameter("categorie", kategorie);
        return query.getResultList();
    }

    public Challenges findById(Long id) {
        return em.find(Challenges.class, id);
    }
}
