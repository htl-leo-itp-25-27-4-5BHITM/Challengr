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

}
