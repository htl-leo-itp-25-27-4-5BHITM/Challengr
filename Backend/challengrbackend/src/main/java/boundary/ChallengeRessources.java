package boundary;

import boundary.dto.ChallengeDTO;
import control.ChallengeRepository;
import entity.Challenges;
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
    public List<ChallengeDTO> findAllChallenges() {
        return challengeRepository.getAllChallenges()
                .stream()
                .map(this::toDTO)
                .toList();
    }

    @GET
    @Path("/{kategorie}")
    public List<ChallengeDTO> findChallengesByKat(@PathParam("kategorie") String kategorie) {
        return challengeRepository.findChallengesByKat(kategorie)
                .stream()
                .map(this::toDTO)
                .toList();
    }

    private ChallengeDTO toDTO(Challenges ch) {
        String categoryName = ch.getChallengeCategory().getName();

        List<String> choices = null;
        Integer correctIndex = null;

        if ("Wissen".equalsIgnoreCase(categoryName)) {
            choices = List.of(
                    ch.getOptionA(),
                    ch.getOptionB(),
                    ch.getOptionC(),
                    ch.getOptionD()
            );
            correctIndex = ch.getCorrectIndex();
        }

        return new ChallengeDTO(
                ch.getId(),
                ch.getText(),
                categoryName,
                choices,
                correctIndex
        );
    }
}
