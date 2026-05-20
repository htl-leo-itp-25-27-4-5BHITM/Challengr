package boundary;

import boundary.dto.ChallengeDTO;
import boundary.dto.ChallengeCreateDTO;
import control.ChallengeCategoriesRepository;
import control.ChallengeRepository;
import entity.ChallengeCategory;
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

    @Inject
    ChallengeCategoriesRepository categoriesRepository;

    @GET
    public List<ChallengeDTO> findAllChallenges() {
        return challengeRepository.getAllChallenges()
                .stream()
                .map(this::toDTO)
                .toList();
    }

    @POST
    public ChallengeDTO createChallenge(ChallengeCreateDTO dto) {
        if (dto == null) {
            throw new WebApplicationException("Missing body", 400);
        }
        if (dto.text() == null || dto.text().isBlank()) {
            throw new WebApplicationException("text is required", 400);
        }
        if (dto.category() == null || dto.category().isBlank()) {
            throw new WebApplicationException("category is required", 400);
        }

        ChallengeCategory category = categoriesRepository.findByName(dto.category());
        if (category == null) {
            throw new WebApplicationException("Unknown category: " + dto.category(), 400);
        }

        Challenges ch = new Challenges();
        ch.setText(dto.text().trim());
        ch.setChallengeCategory(category);

        // Wissen: validate and store options
        if ("Wissen".equalsIgnoreCase(category.getName())) {
            if (dto.choices() == null || dto.choices().size() != 4) {
                throw new WebApplicationException("choices must have exactly 4 items for Wissen", 400);
            }
            if (dto.correctIndex() == null || dto.correctIndex() < 0 || dto.correctIndex() > 3) {
                throw new WebApplicationException("correctIndex must be 0..3 for Wissen", 400);
            }
            ch.setOptionA(dto.choices().get(0));
            ch.setOptionB(dto.choices().get(1));
            ch.setOptionC(dto.choices().get(2));
            ch.setOptionD(dto.choices().get(3));
            ch.setCorrectIndex(dto.correctIndex());
        } else {
            // Ensure non-wissen challenges don't accidentally store old MC data
            ch.setOptionA(null);
            ch.setOptionB(null);
            ch.setOptionC(null);
            ch.setOptionD(null);
            ch.setCorrectIndex(null);
        }

        Challenges saved = challengeRepository.create(ch);
        return toDTO(saved);
    }

    @GET
    @Path("/id/{id}")
    public ChallengeDTO findChallengeById(@PathParam("id") long id) {
        Challenges ch = challengeRepository.findById(id);
        if (ch == null) {
            throw new NotFoundException("challenge not found");
        }
        return toDTO(ch); // deine bestehende Mapping-Methode
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
