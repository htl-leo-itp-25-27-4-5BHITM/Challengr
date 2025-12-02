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
    public Player createPlayer(Player player) {
        em.persist(player);
        em.flush(); // damit die ID sofort erzeugt wird
        return player;
    }


    public void updatePlayerPos(Player player) {
        Player existing = em.find(Player.class, player.getId());

        existing.setLatitude(player.getLatitude());
        existing.setLongitude(player.getLongitude());

        em.merge(existing);
    }

    public Player findById(Long id) {
        return em.find(Player.class, id);
    }

}
