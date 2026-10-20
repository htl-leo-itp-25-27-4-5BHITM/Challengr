package control;

import control.QuestCatalog.Event;
import control.QuestCatalog.Metric;
import control.QuestCatalog.Task;
import entity.Battle;
import entity.Player;
import entity.QuestClaim;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.WebApplicationException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Tagesaufgaben und Events: Fortschritt wird aus den Spieldaten berechnet (Battles, Check-ins, Spieltage, Freunde),
 * nur das Abholen wird gespeichert. Coins = {@link Player#getPoints()} (Währung für den späteren Shop).
 */
@ApplicationScoped
public class QuestService {

    static final ZoneId ZONE = ActivityTracker.ZONE;
    /** Battle-Zeitstempel sind LocalDateTime in der Zeitzone des Servers */
    private static final ZoneId SERVER_ZONE = ZoneId.systemDefault();

    public record TaskView(String id, String title, String icon, int target, int progress, int coins, boolean claimed) {
        public boolean done() { return progress >= target; }
    }

    public record EventView(String id, String title, String subtitle, String startsOn, String endsOn, boolean active,
                            String rewardCharacter, int rewardCoins, List<TaskView> tasks, boolean completed, boolean claimed) {}

    public record Board(int coins, String day, String resetsAt, List<TaskView> daily, List<EventView> events) {}

    @Inject
    EntityManager em;

    @Inject
    FriendshipRepository friendships;

    @Inject
    ActivityTracker activity;

    public static LocalDate today() {
        return LocalDate.now(ZONE);
    }

    @Transactional
    public Board board(String playerId) {
        Player player = em.find(Player.class, playerId);
        if (player == null) throw new WebApplicationException("Player not found", 404);
        activity.seen(playerId); // "Schau heute vorbei" zählt sofort
        LocalDate today = today();
        Set<String> claimed = claimedKeys(playerId);
        Counter todayCount = new Counter(playerId, today, today);

        List<TaskView> daily = QuestCatalog.dailyFor(today).stream()
                .map(t -> view(t, todayCount, claimed.contains(QuestCatalog.dailyKey(today, t))))
                .toList();

        List<EventView> events = QuestCatalog.EVENTS.stream()
                // laufende Events; beendete noch eine Woche lang (zum Abholen, falls am letzten Tag geschafft)
                .filter(e -> !today.isBefore(e.start()) && !today.isAfter(e.end().plusDays(7)))
                .map(e -> eventView(e, playerId, claimed))
                .toList();

        String resetsAt = today.plusDays(1).atStartOfDay(ZONE).toInstant().toString();
        return new Board(player.getPoints(), today.toString(), resetsAt, daily, events);
    }

    /** Tagesaufgabe abholen: Coins gutschreiben. */
    @Transactional
    public Board claimDaily(String playerId, String taskId) {
        LocalDate today = today();
        Task task = QuestCatalog.dailyFor(today).stream().filter(t -> t.id().equals(taskId)).findFirst()
                .orElseThrow(() -> new WebApplicationException("Diese Aufgabe gibt es heute nicht", 404));
        String key = QuestCatalog.dailyKey(today, task);
        if (claimedKeys(playerId).contains(key)) throw new WebApplicationException("Schon abgeholt", 409);
        if (new Counter(playerId, today, today).of(task.metric()) < task.target())
            throw new WebApplicationException("Aufgabe noch nicht geschafft", 409);
        credit(playerId, key, today, task.coins());
        return board(playerId);
    }

    /** Event-Belohnung abholen: Coins + Figur (die Figur hängt am gespeicherten Abholen). */
    @Transactional
    public Board claimEvent(String playerId, String eventId) {
        Event event = QuestCatalog.event(eventId).orElseThrow(() -> new WebApplicationException("Unbekanntes Event", 404));
        LocalDate today = today();
        if (today.isBefore(event.start())) throw new WebApplicationException("Event hat noch nicht begonnen", 409);
        String key = QuestCatalog.eventKey(eventId);
        if (claimedKeys(playerId).contains(key)) throw new WebApplicationException("Schon abgeholt", 409);
        if (!eventView(event, playerId, Set.of()).completed()) throw new WebApplicationException("Event noch nicht geschafft", 409);
        credit(playerId, key, today, event.rewardCoins());
        return board(playerId);
    }

    /** Events, deren Belohnung der Spieler abgeholt hat (für Event-Figuren). */
    public Set<String> claimedEvents(String playerId) {
        Set<String> out = new HashSet<>();
        for (String k : claimedKeys(playerId)) if (k.startsWith("event:")) out.add(k.substring("event:".length()));
        return out;
    }

    private void credit(String playerId, String key, LocalDate day, int coins) {
        em.persist(new QuestClaim(playerId, key, day, coins));
        Player p = em.find(Player.class, playerId, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        p.setPoints(p.getPoints() + coins);
        em.flush(); // Unique-Constraint greift sofort, falls zweimal gleichzeitig abgeholt wird
    }

    private EventView eventView(Event e, String playerId, Set<String> claimed) {
        // Fortschritt nur innerhalb des Event-Zeitraums
        Counter c = new Counter(playerId, e.start(), e.end());
        List<TaskView> tasks = e.tasks().stream().map(t -> view(t, c, false)).toList();
        boolean completed = tasks.stream().allMatch(TaskView::done);
        return new EventView(e.id(), e.title(), e.subtitle(), e.start().toString(), e.end().toString(), e.isActive(today()),
                e.rewardCharacter(), e.rewardCoins(), tasks, completed, claimed.contains(QuestCatalog.eventKey(e.id())));
    }

    private static TaskView view(Task t, Counter c, boolean claimed) {
        return new TaskView(t.id(), t.title(), t.icon(), t.target(), Math.min(c.of(t.metric()), t.target()), t.coins(), claimed);
    }

    private Set<String> claimedKeys(String playerId) {
        return new HashSet<>(em.createQuery("SELECT c.questKey FROM QuestClaim c WHERE c.playerId = :p", String.class)
                .setParameter("p", playerId).getResultList());
    }

    /** Zählt alles für einen Spieler in einem Zeitraum (Wiener Kalendertage, beide inklusive). Battles nur einmal geladen. */
    private final class Counter {
        private final String playerId;
        private final LocalDate from, to;
        private List<Battle> battles;

        Counter(String playerId, LocalDate from, LocalDate to) {
            this.playerId = playerId;
            this.from = from;
            this.to = to;
        }

        int of(Metric m) {
            return switch (m) {
                case ACTIVE_DAYS -> count("SELECT COUNT(a) FROM PlayerActivity a WHERE a.playerId = :p AND a.day BETWEEN :f AND :t");
                case CHECKINS -> count("SELECT COUNT(c) FROM HotspotCheckin c WHERE c.playerId = :p AND c.day BETWEEN :f AND :t");
                case DAILY_QUESTS -> (int) (long) em.createQuery(
                                "SELECT COUNT(c) FROM QuestClaim c WHERE c.playerId = :p AND c.questKey LIKE 'daily:%' AND c.day BETWEEN :f AND :t", Long.class)
                        .setParameter("p", playerId).setParameter("f", from).setParameter("t", to).getSingleResult();
                case FRIENDS -> friendships.listFriendIds(playerId).size();
                case BATTLES -> battles().size();
                case LEAGUE_WINS -> (int) battles().stream().filter(b -> BattleMode.from(b.getType()).isRanked())
                        .filter(b -> b.getWinner() != null && playerId.equals(b.getWinner().getId())).count();
                case QUIZ_SHOWS -> (int) battles().stream().filter(b -> BattleMode.from(b.getType()) == BattleMode.RANKED_KNOWLEDGE).count();
                case REALLIFE -> (int) battles().stream().filter(b -> BattleMode.from(b.getType()) == BattleMode.RANKED_REALLIFE).count();
                case FRIENDLIES -> (int) battles().stream().filter(b -> BattleMode.from(b.getType()) == BattleMode.FRIENDLY).count();
                case FRIEND_BATTLES -> {
                    Set<String> friends = new HashSet<>(friendships.listFriendIds(playerId));
                    yield (int) battles().stream().filter(b -> friends.contains(opponent(b))).count();
                }
            };
        }

        private int count(String jpql) {
            return (int) (long) em.createQuery(jpql, Long.class)
                    .setParameter("p", playerId).setParameter("f", from).setParameter("t", to).getSingleResult();
        }

        private String opponent(Battle b) {
            return playerId.equals(b.getFromPlayer().getId()) ? b.getToPlayer().getId() : b.getFromPlayer().getId();
        }

        private List<Battle> battles() {
            if (battles == null) {
                LocalDateTime start = from.atStartOfDay(ZONE).withZoneSameInstant(SERVER_ZONE).toLocalDateTime();
                LocalDateTime end = to.plusDays(1).atStartOfDay(ZONE).withZoneSameInstant(SERVER_ZONE).toLocalDateTime();
                battles = em.createQuery("""
                                SELECT b FROM Battle b
                                WHERE (b.fromPlayer.id = :p OR b.toPlayer.id = :p) AND b.status = 'DONE'
                                AND b.statusChangedAt >= :s AND b.statusChangedAt < :e
                                """, Battle.class)
                        .setParameter("p", playerId).setParameter("s", start).setParameter("e", end).getResultList();
            }
            return battles;
        }
    }
}
