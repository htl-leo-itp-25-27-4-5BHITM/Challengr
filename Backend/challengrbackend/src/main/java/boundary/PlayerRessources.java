package boundary;

import boundary.dto.NearbyRequest;
import boundary.dto.PlayerDTO;
import control.PlayerRepository;
import entity.Player;
import jakarta.enterprise.event.Event;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.util.List;
import java.util.stream.Collectors;

@Path("/api/players")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class PlayerRessources {
    @Inject
    PlayerRepository playerRepository;

    @Inject
    EntityManager em;


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

    @POST
    @Path("/nearby")
    @Transactional
    public List<PlayerDTO> getNearbyPlayers(NearbyRequest req) {

        List<Player> allPlayers = em.createQuery("SELECT p FROM Player p", Player.class)
                .getResultList();

        return allPlayers.stream()
                .filter(p ->
                        // Eigener Spieler immer anzeigen
                        p.getId().equals(req.playerId)
                                ||
                                // andere Spieler nach Distanz
                                distance(
                                        req.latitude,
                                        req.longitude,
                                        p.getLatitude(),
                                        p.getLongitude()
                                ) <= req.radius
                )
                .map(p -> {
                    PlayerDTO dto = new PlayerDTO();
                    dto.id = p.getId();
                    dto.name = p.getName();
                    dto.latitude = p.getLatitude();
                    dto.longitude = p.getLongitude();
                    return dto;
                })
                .collect(Collectors.toList());
    }

    // Haversine in Metern
    private double distance(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371000; // Meter
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);

        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);

        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }


}
