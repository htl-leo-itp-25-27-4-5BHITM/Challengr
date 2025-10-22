package at.htl;

import at.htl.model.FakeChallengeData;
import at.htl.model.ChallengeCategoryDTO;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import java.util.*;

@Path("/challenge")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ChallengeResource {

    @GET
    @Path("/{category}")
    public ChallengeCategoryDTO getChallengesByCategory(@PathParam("category") String category) {
        return FakeChallengeData.challengesByCategory.get(category);
    }


    @GET
    @Path("/pretty")
    @Produces(MediaType.APPLICATION_JSON)
    public String getAllChallengesPretty() throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        return mapper.writerWithDefaultPrettyPrinter()
                .writeValueAsString(FakeChallengeData.challengesByCategory);
    }


    @GET
    public Map<String, ChallengeCategoryDTO> getAllChallenges() {
        return FakeChallengeData.challengesByCategory;
    }
}
