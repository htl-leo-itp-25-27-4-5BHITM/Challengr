package boundary;

import control.ChallengeRepository;
import control.PlayerRepository;
import entity.Challenges;
import entity.Player;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

@Path("/api/challenges")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class ChallengeRessources {
    @Inject
    ChallengeRepository challengeRepository;


    @GET
    public List<Challenges> findAllChallenges() {
        return challengeRepository.getAllChallenges();
    }

    @GET
    @Path("/{kategorie}")
    public List<Challenges> findChallengesByKat(@PathParam("kategorie") String kategorie) {
        return challengeRepository.findChallengesByKat(kategorie);
    }

}
