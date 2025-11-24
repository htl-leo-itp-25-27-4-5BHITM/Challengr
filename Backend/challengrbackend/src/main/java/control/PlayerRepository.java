package control;

import entity.Player;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;

import java.util.List;

@ApplicationScoped
public class PlayerRepository {

    @Inject
    EntityManager em;

    public List<Player> getAllPlayers() {
        var query = em.createQuery("SELECT p FROM Player p", Player.class);

        return query.getResultList();
    }

}
