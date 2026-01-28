package boundary;

import control.RankRepository;
import entity.Rank;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

@Path("/api/ranks")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class RankResources {
    @Inject
    RankRepository rankRepository;

    @GET
    public List<Rank> getAllRanks(){
        return rankRepository.getAllRanks();
    }
}
