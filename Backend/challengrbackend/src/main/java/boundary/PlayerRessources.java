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
    @Transactional
    public PlayerDTO createPlayer(Player player) {
        Player saved = playerRepository.createPlayer(player);

        return new PlayerDTO(
                saved.getId(),
                saved.getName(),
                saved.getLatitude(),
                saved.getLongitude()
        );
    }

    @PUT
    public void updatePlayerPos(Player player) {
        playerRepository.updatePlayerPos(player);
    }

    @PUT
    @Path("/{id}")
    @Transactional
    public PlayerDTO updatePlayer(@PathParam("id") Long id, PlayerDTO dto) {
        Player player = playerRepository.findById(id);
        if (player == null) {
            throw new WebApplicationException("Player not found", 404);
        }

        // Name optional mit updaten, falls gewünscht:
        if (dto.name() != null) {
            player.setName(dto.name());
        }

        player.setLatitude(dto.latitude());
        player.setLongitude(dto.longitude());

        return new PlayerDTO(
                player.getId(),
                player.getName(),
                player.getLatitude(),
                player.getLongitude()
        );
    }


    @GET
    @Path("/{id}")
    public PlayerDTO getPlayer(@PathParam("id") Long id) {
        Player player = playerRepository.findById(id);
        if (player == null) {
            throw new WebApplicationException("Player not found", 404);
        }
        return new PlayerDTO(
                player.getId(),
                player.getName(),
                player.getLatitude(),
                player.getLongitude()
        );
    }


    @POST
    @Path("/nearby")
    @Transactional
    public List<PlayerDTO> getNearbyPlayers(NearbyRequest req) {

        List<Player> allPlayers = em.createQuery(
                "SELECT p FROM Player p", Player.class
        ).getResultList();

        return allPlayers.stream()
                .filter(p -> {
                    // Spieler ohne Koords rausfiltern
                    if (p.getLatitude() == 0 || p.getLongitude() == 0) {
                        return false;
                    }
                    // eigener Spieler immer anzeigen
                    if (p.getId().equals(req.playerId())) {
                        return false;
                    }
                    // Distanz in Metern berechnen
                    double dist = distance(
                            req.latitude(),
                            req.longitude(),
                            p.getLatitude(),
                            p.getLongitude()
                    );
                    return dist <= req.radius();
                })
                .map(p -> new PlayerDTO(
                        p.getId(),
                        p.getName(),
                        p.getLatitude(),
                        p.getLongitude()
                ))
                .toList();
    }

    // Haversine in Metern
    private double distance(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371000;
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
