package boundary;

import control.PlayerRepository;
import entity.Player;
import jakarta.enterprise.event.Event;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

@Path("/api/players")
public class PlayerRessources {
    @Inject
    PlayerRepository playerRepository;


    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Player> findAllCars() {
        return playerRepository.getAllPlayers();
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public void createPlayer(Player player) {
        playerRepository.createPlayer(player);
    }

    @PUT
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public void updatePlayerPos(Player player) {
        playerRepository.updatePlayerPos(player);
    }

}
