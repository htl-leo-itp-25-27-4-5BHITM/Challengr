package control;

import entity.ChallengeCategory;
import entity.Challenges;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;

import java.util.List;

@ApplicationScoped
public class ChallengeCategoriesRepository {

    @Inject
    EntityManager em;

    public List<ChallengeCategory> getAllCategories() {
        var query = em.createQuery("SELECT cc FROM ChallengeCategory cc", ChallengeCategory.class);

        return query.getResultList();
    }

    public ChallengeCategory findByName(String name) {
        if (name == null || name.isBlank()) {
            return null;
        }

        return em.createQuery(
                        "SELECT cc FROM ChallengeCategory cc WHERE LOWER(cc.name) = :name",
                        ChallengeCategory.class
                )
                .setParameter("name", name.trim().toLowerCase())
                .setMaxResults(1)
                .getResultStream()
                .findFirst()
                .orElse(null);
    }

}
