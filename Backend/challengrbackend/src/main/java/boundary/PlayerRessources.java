package boundary;

import boundary.dto.NearbyRequest;
import boundary.dto.PlayerDTO;
import boundary.dto.PlayerPointsHistoryDTO;
import control.PlayerRepository;
import entity.Battle;
import entity.Player;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

@Path("/api/players")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class PlayerRessources {

    @Inject
    PlayerRepository playerRepository;

    @Inject
    BattleService battleService;

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
                saved.getLongitude(),
                saved.getPoints(),
                battleService.rankNameForPoints(saved.getPoints())
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
        // Punkte kommen aus Battles → hier NICHT setzen

        return new PlayerDTO(
                player.getId(),
                player.getName(),
                player.getLatitude(),
                player.getLongitude(),
                player.getPoints(),
                battleService.rankNameForPoints(player.getPoints())
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
                player.getLongitude(),
                player.getPoints(),
                battleService.rankNameForPoints(player.getPoints())
        );
    }

    @GET
    @Path("/nearby")
    public List<PlayerDTO> getNearbyPlayers(
            @QueryParam("playerId") long playerId,
            @QueryParam("latitude") double latitude,
            @QueryParam("longitude") double longitude,
            @QueryParam("radius") double radius
    ) {
        List<Player> allPlayers = em.createQuery(
                "SELECT p FROM Player p", Player.class
        ).getResultList();

        return allPlayers.stream()
                .filter(p -> {
                    if (p.getLatitude() == 0 || p.getLongitude() == 0) {
                        return false;
                    }
                    if (p.getId().equals(playerId)) {
                        return false;
                    }
                    double dist = distance(
                            latitude,
                            longitude,
                            p.getLatitude(),
                            p.getLongitude()
                    );
                    return dist <= radius;
                })
                .map(p -> new PlayerDTO(
                        p.getId(),
                        p.getName(),
                        p.getLatitude(),
                        p.getLongitude(),
                        p.getPoints(),
                        battleService.rankNameForPoints(p.getPoints())
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

    public static class PlayerPointsDTO {
        public long playerId;
        public int points;

        public PlayerPointsDTO() {}

        public PlayerPointsDTO(long playerId, int points) {
            this.playerId = playerId;
            this.points = points;
        }
    }

    public static class PlayerStatsDTO {
        public int totalChallenges;
        public int wonChallenges;

        public PlayerStatsDTO() {}

        public PlayerStatsDTO(int totalChallenges, int wonChallenges) {
            this.totalChallenges = totalChallenges;
            this.wonChallenges = wonChallenges;
        }
    }

    public static class BattleHistoryDTO {
        public Long id;
        public String createdAt;
        public String challengeText;
        public String category;
        public String opponentName;
        public String winnerName;
        public String status;
        public int pointsDelta;
        public boolean won;

        public BattleHistoryDTO() {}

        public BattleHistoryDTO(Long id,
                                String createdAt,
                                String challengeText,
                                String category,
                                String opponentName,
                                String winnerName,
                                String status,
                                int pointsDelta,
                                boolean won) {
            this.id = id;
            this.createdAt = createdAt;
            this.challengeText = challengeText;
            this.category = category;
            this.opponentName = opponentName;
            this.winnerName = winnerName;
            this.status = status;
            this.pointsDelta = pointsDelta;
            this.won = won;
        }
    }

    @GET
    @Path("/{id}/stats")
    public PlayerStatsDTO getStats(@PathParam("id") Long id) {
        Player player = playerRepository.findById(id);
        if (player == null) {
            throw new NotFoundException();
        }

        var battles = playerRepository.findDoneBattlesForPlayer(player);

        int total = battles.size();
        int won   = (int) battles.stream()
                .filter(b -> b.getWinner() != null && b.getWinner().getId().equals(id))
                .count();

        return new PlayerStatsDTO(total, won);
    }


    @GET
    @Path("/{id}/points")
    public PlayerPointsDTO getPlayerPoints(@PathParam("id") Long id) {
        Player p = playerRepository.findById(id);
        if (p == null) {
            throw new NotFoundException();
        }
        return new PlayerPointsDTO(p.getId(), p.getPoints()); // getPoints() = Feld in deiner Player-Entity
    }

    @GET
    @Path("/{id}/battles")
    public List<BattleHistoryDTO> getBattleHistory(@PathParam("id") Long id) {
        Player player = playerRepository.findById(id);
        if (player == null) {
            throw new NotFoundException();
        }

        var battles = playerRepository.findDoneBattlesForPlayer(player);
        battles.sort((a, b) -> b.getCreatedAt().compareTo(a.getCreatedAt()));

        List<BattleHistoryDTO> history = new java.util.ArrayList<>();

        for (Battle b : battles) {
            boolean isFrom = b.getFromPlayer().getId().equals(player.getId());
            Player opponent = isFrom ? b.getToPlayer() : b.getFromPlayer();
            boolean won = b.getWinner() != null && b.getWinner().getId().equals(player.getId());

            int delta;
            if (won) {
                delta = b.getWinnerPointsDelta() != null ? b.getWinnerPointsDelta() : 0;
            } else {
                delta = b.getLoserPointsDelta() != null ? b.getLoserPointsDelta() : 0;
            }

            String category = b.getCategory() != null ? b.getCategory().getName() : "";
            String challengeText = b.getChallenge() != null ? b.getChallenge().getText() : "";
            String winnerName = b.getWinner() != null ? b.getWinner().getName() : null;

            history.add(new BattleHistoryDTO(
                    b.getId(),
                    b.getCreatedAt().toString(),
                    challengeText,
                    category,
                    opponent != null ? opponent.getName() : "",
                    winnerName,
                    b.getStatus(),
                    delta,
                    won
            ));
        }

        return history;
    }

    @GET
    @Path("/{id}/log")
    public int getBattleCount(@PathParam("id") Long id) {

        Player player = playerRepository.findById(id);
        if (player == null) {
            throw new NotFoundException();
        }

        var battles = playerRepository.findDoneBattlesForPlayer(player);

        return battles.size();
    }

    @GET
    @Path("/{id}/streak")
    public int getStreak(@PathParam("id") Long id) {

        Player player = playerRepository.findById(id);
        if (player == null) {
            throw new NotFoundException();
        }

        var battles = playerRepository.findDoneBattlesForPlayer(player);

        // Alle unterschiedlichen Tage sammeln
        var battleDays = battles.stream()
                .map(b -> b.getCreatedAt().toLocalDate())
                .collect(java.util.stream.Collectors.toSet());

        if (battleDays.isEmpty()) {
            return 0;
        }

        int streak = 0;
        java.time.LocalDate current = java.time.LocalDate.now();

        while (battleDays.contains(current)) {
            streak++;
            current = current.minusDays(1);
        }

        return streak;
    }


    @GET
    @Path("/{id}/points-history")
    public List<PlayerPointsHistoryDTO> getPointsHistory(@PathParam("id") Long id) {

        Player player = playerRepository.findById(id);
        if (player == null) {
            throw new NotFoundException();
        }

        var battles = playerRepository.findDoneBattlesForPlayer(player);

        // nach datum sortieren (alt → neu)
        battles.sort((a, b) -> a.getCreatedAt().compareTo(b.getCreatedAt()));

        List<PlayerPointsHistoryDTO> history = new java.util.ArrayList<>();

        int currentPoints = player.getPoints(); // 🔥 aktueller stand!

        // rückwärts durchgehen
        for (int i = battles.size() - 1; i >= 0; i--) {
            Battle b = battles.get(i);

            // aktuellen stand speichern
            history.add(0, new PlayerPointsHistoryDTO(
                    b.getCreatedAt().toLocalDate().toString(),
                    currentPoints
            ));

            int delta;

            if (b.getWinner() != null && b.getWinner().getId().equals(player.getId())) {
                delta = b.getWinnerPointsDelta();
            } else {
                delta = b.getLoserPointsDelta();
            }

            currentPoints -= delta; // 🔥 rückwärts rechnen!
        }

        return history;
    }


}
