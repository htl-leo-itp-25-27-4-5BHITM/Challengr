package boundary;

import control.ChallengeCategoriesRepository;
import control.ChallengeRepository;
import entity.ChallengeCategory;
import entity.Challenges;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

@Path("/api/challenges/categories")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class ChallengeCategoriesRessources {
    @Inject
    ChallengeCategoriesRepository categoriesRepository;


    @GET
    public List<ChallengeCategory> findAllCategories() {
        return categoriesRepository.getAllCategories();
    }

}
