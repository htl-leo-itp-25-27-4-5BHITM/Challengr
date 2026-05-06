package control;

import entity.Battle;
import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.util.List;

@ApplicationScoped
public class PlayerRepository {

    @Inject
    EntityManager em;

    public List<Player> getAllPlayers() {
        var query = em.createQuery("SELECT p FROM Player p", Player.class);

        return query.getResultList();
    }

    @Transactional
    public Player createPlayer(Player player) {
        if (player == null) {
            throw new IllegalArgumentException("player must not be null");
        }

        String normalizedName = normalize(player.getName());
        String normalizedId = normalize(player.getId());

        if (normalizedId == null) {
            if (normalizedName != null && normalizedName.equalsIgnoreCase("WebappSpieler")) {
                normalizedId = "3";
            } else {
                throw new IllegalArgumentException("player id (keycloak id) must not be null");
            }
        }

        player.setName(normalizedName);
        player.setId(normalizedId);

        Player existingById = findById(normalizedId);
        if (existingById != null) {
            if (normalizedName != null && !normalizedName.equals(existingById.getName())) {
                existingById.setName(normalizedName);
                save(existingById);
            }
            return existingById;
        }

        em.persist(player);
        return player;
    }

    private String normalize(String value) {
        if (value == null) {
            return null;
        }

        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private Player findByNameIgnoreCase(String name) {
        if (name == null || name.isBlank()) {
            return null;
        }

        return em.createQuery(
                        "SELECT p FROM Player p WHERE LOWER(p.name) = :name",
                        Player.class
                )
                .setParameter("name", name.toLowerCase())
                .setMaxResults(1)
                .getResultStream()
                .findFirst()
                .orElse(null);
    }

    @Transactional
    public Player save(Player player) {
        if (player.getId() == null) {
            throw new IllegalArgumentException("player id must be set");
        }
        return em.merge(player);
    }

    @Transactional
    public void updatePlayerPos(Player player) {
        if (player == null || player.getId() == null) {
            throw new IllegalArgumentException("player id must be set");
        }

        Player existing = em.find(Player.class, player.getId());
        if (existing == null) {
            throw new IllegalArgumentException("Player not found");
        }

        existing.setLatitude(player.getLatitude());
        existing.setLongitude(player.getLongitude());

        em.merge(existing);
    }

    public List<Battle> findDoneBattlesForPlayer(Player player) {
        return em.createQuery("""
            SELECT b FROM Battle b
            WHERE b.status = 'DONE'
            AND (b.fromPlayer = :player OR b.toPlayer = :player)
        """, Battle.class)
                .setParameter("player", player)
                .getResultList();
    }

    public Player findById(String id) {
        return em.find(Player.class, id);
    }

    public List<Player> findNearbyPlayers(String currentPlayerId, double latitude, double longitude, double radius) {
        List<Player> allPlayers = em.createQuery("SELECT p FROM Player p", Player.class).getResultList();

        return allPlayers.stream()
                .filter(p -> {
                    if (p.getId() == null || p.getId().equals(currentPlayerId)) return false;
                    if (p.getLatitude() == 0 || p.getLongitude() == 0) return false;
                    double dist = distance(latitude, longitude, p.getLatitude(), p.getLongitude());
                    return dist <= radius;
                })
                .toList();
    }

    private double distance(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

}
