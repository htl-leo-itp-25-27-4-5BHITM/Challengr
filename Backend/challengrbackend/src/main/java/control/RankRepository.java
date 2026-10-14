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

    // Rank passend zu bestimmten Trophäen finden; über dem höchsten Rang bleibt man im höchsten (nach oben offen)
    public Rank rankForPoints(int points, List<Rank> ranks) {
        return ranks.stream()
                .filter(r -> points >= r.getMin() && points <= r.getMax())
                .findFirst()
                .orElseGet(() -> ranks.stream()
                        .filter(r -> points >= r.getMin())
                        .max(Comparator.comparingInt(Rank::getMin))
                        .orElse(null));
    }

    // Index im sortierten Rank‑Array (für getOrder-Ersatz)
    public int indexOfRank(Rank rank, List<Rank> ranks) {
        List<Rank> sorted = ranks.stream()
                .sorted(Comparator.comparingInt(Rank::getMin))
                .toList();
        return sorted.indexOf(rank); // 0-basiger „order“-Wert
    }
}
