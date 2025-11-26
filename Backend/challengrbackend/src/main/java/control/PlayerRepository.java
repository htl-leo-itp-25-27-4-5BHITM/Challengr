package control;

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
    public void createPlayer(Player player) {
        em.persist(player);
    }

    @Transactional
    public void updatePlayerPos(Player player) {
        if (player.getId() == null) {
            em.persist(player); // Spieler neu anlegen
            System.out.println("Created new player with name: " + player.getName());
        } else {
            Player existing = em.find(Player.class, player.getId());
            if (existing != null) {
                existing.setLatitude(player.getLatitude());
                existing.setLongitude(player.getLongitude());
                em.merge(existing);
            } else {
                em.persist(player); // neu erstellen
                System.out.println("Player not found, created new player with name: " + player.getName());
            }
        }
    }


}
