package control;

import entity.Battle;
import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceException;
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

        // Client darf bei create keine ID vorgeben.
        player.setId(null);

        String normalizedName = normalize(player.getName());
        String normalizedKeycloakId = normalize(player.getKeycloakId());
        player.setName(normalizedName);
        player.setKeycloakId(normalizedKeycloakId);

        if (normalizedKeycloakId != null) {
            Player existingByKeycloakId = findByKeycloakId(normalizedKeycloakId);
            if (existingByKeycloakId != null) {
                if (normalizedName != null && !normalizedName.equals(existingByKeycloakId.getName())) {
                    existingByKeycloakId.setName(normalizedName);
                    save(existingByKeycloakId);
                }
                return existingByKeycloakId;
            }
        }

        if (normalizedName != null) {
            // Fallback für Alt-Daten ohne keycloakId.
            Player existing = findByNameIgnoreCase(normalizedName);
            if (existing != null) {
                if (existing.getKeycloakId() == null && normalizedKeycloakId != null) {
                    existing.setKeycloakId(normalizedKeycloakId);
                    save(existing);
                }
                return existing;
            }
        }

        try {
            em.persist(player);
            em.flush(); // damit die ID sofort erzeugt wird
            return player;
        } catch (PersistenceException ex) {
            if (!isDuplicatePlayerPrimaryKey(ex)) {
                if (normalizedKeycloakId != null) {
                    Player existingByKeycloakId = findByKeycloakId(normalizedKeycloakId);
                    if (existingByKeycloakId != null) {
                        return existingByKeycloakId;
                    }
                }
                throw ex;
            }

            // Cloud-DB kann eine verschobene Sequence haben (z.B. nach manuellen Inserts).
            realignPlayerIdSequence();

            em.clear();
            player.setId(null);
            em.persist(player);
            em.flush();
            return player;
        }
    }

    private String normalize(String value) {
        if (value == null) {
            return null;
        }

        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private Player findByKeycloakId(String keycloakId) {
        if (keycloakId == null || keycloakId.isBlank()) {
            return null;
        }

        return em.createQuery(
                        "SELECT p FROM Player p WHERE p.keycloakId = :keycloakId",
                        Player.class
                )
                .setParameter("keycloakId", keycloakId)
                .setMaxResults(1)
                .getResultStream()
                .findFirst()
                .orElse(null);
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

    private boolean isDuplicatePlayerPrimaryKey(Throwable throwable) {
        Throwable current = throwable;
        while (current != null) {
            String msg = current.getMessage();
            if (msg != null
                    && msg.contains("duplicate key value")
                    && msg.contains("player_pkey")) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    private void realignPlayerIdSequence() {
        Object sequenceNameObj = em.createNativeQuery(
                        "SELECT pg_get_serial_sequence('player', 'id')"
                )
                .getSingleResult();

        if (sequenceNameObj == null) {
            return;
        }

        String sequenceName = sequenceNameObj.toString();
        em.createNativeQuery(
                        "SELECT setval(CAST(:seqName AS regclass), COALESCE((SELECT MAX(id) FROM player), 0) + 1, false)"
                )
                .setParameter("seqName", sequenceName)
                .getSingleResult();
    }

    @Transactional
    public Player save(Player player) {
        if (player.getId() == null) {
            em.persist(player);
            return player;
        } else {
            return em.merge(player);
        }
    }

    @Transactional
    public void updatePlayerPos(Player player) {
        Player existing = em.find(Player.class, player.getId());

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

    public Player findById(Long id) {
        return em.find(Player.class, id);
    }

    public List<Player> findNearbyPlayers(long currentPlayerId, double latitude, double longitude, double radius) {
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
