package boundary;

import control.PlayerRepository;
import entity.Player;
import jakarta.enterprise.event.Event;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

@Path("/api/players")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class PlayerRessources {
    @Inject
    PlayerRepository playerRepository;


    @GET
    public List<Player> findAllPlayers() {
        return playerRepository.getAllPlayers();
    }

    @POST
    public void createPlayer(Player player) {
        playerRepository.createPlayer(player);
    }

    @PUT
    public void updatePlayerPos(Player player) {
        playerRepository.updatePlayerPos(player);
    }

}
