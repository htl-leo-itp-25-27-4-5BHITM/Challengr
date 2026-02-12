package control;

import entity.Rank;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;

import java.util.Comparator;
import java.util.List;

@ApplicationScoped
public class RankRepository {

    @Inject
    EntityManager em;

    public List<Rank> getAllRanks() {
        return em.createQuery("SELECT r FROM Rank r", Rank.class)
                .getResultList();
    }

    // Rank passend zu bestimmten Punkten finden
    public Rank rankForPoints(int points, List<Rank> ranks) {
        return ranks.stream()
                .filter(r -> points >= r.getMin() && points <= r.getMax())
                .findFirst()
                .orElse(null);
    }

    // Index im sortierten Rank‑Array (für getOrder-Ersatz)
    public int indexOfRank(Rank rank, List<Rank> ranks) {
        List<Rank> sorted = ranks.stream()
                .sorted(Comparator.comparingInt(Rank::getMin))
                .toList();
        return sorted.indexOf(rank); // 0-basiger „order“-Wert
    }
}
