package at.htl;

import at.htl.model.FakeChallengeData;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import java.util.*;

@Path("/challenge") // Pfad jetzt korrekt
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ChallengeResource {

    @GET
    @Path("/{category}")
    public List<String> getChallengesByCategory(@PathParam("category") String category) {
        return FakeChallengeData.challengesByCategory.getOrDefault(category, List.of());
    }

    @GET
    public Map<String, List<String>> getAllChallenges() {
        return FakeChallengeData.challengesByCategory;
    }

}
