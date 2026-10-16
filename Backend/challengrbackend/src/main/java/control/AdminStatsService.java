package control;

import entity.Battle;
import entity.HotspotCheckin;
import entity.Player;
import entity.PlayerActivity;
import entity.PlayerReport;
import entity.Rank;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Zahlen fürs Admin-Dashboard aus den echten Spieldaten. Rechnet alles im Speicher –
 * bei ein paar hundert Spielern und Battles ist das schneller und einfacher als viele SQL-Abfragen.
 */
@ApplicationScoped
public class AdminStatsService {

    private static final ZoneId ZONE = ActivityTracker.ZONE;
    /** Battle-Zeitstempel sind LocalDateTime in der Zeitzone des Servers */
    private static final ZoneId SERVER_ZONE = ZoneId.systemDefault();

    public record Totals(long players, long activeToday, long active7d, long newPlayers7d, long returning7d,
                         long battlesToday, long battlesTotal, long checkinsToday, long openReports, long activeBans) {}

    public record DayPoint(String day, long activePlayers, long newPlayers,
                           long quiz, long realLife, long friendly, long checkins) {}

    public record NamedCount(String name, long count) {}

    public record LeaderRow(String name, String rank, int trophies, long battles, long wins, String lastSeen) {}

    public record Stats(String generatedAt, int days, Totals totals, List<DayPoint> daily, long[] battlesByHour,
                       List<NamedCount> modes, List<NamedCount> outcomes, List<NamedCount> ranks,
                       List<NamedCount> characters, List<NamedCount> topChallenges, List<LeaderRow> leaderboard) {}

    @Inject
    EntityManager em;

    @Inject
    RankRepository rankRepository;

    @Transactional
    public Stats stats(int days) {
        LocalDate today = LocalDate.now(ZONE);
        LocalDate from = today.minusDays(days - 1L);

        List<Player> players = em.createQuery("SELECT p FROM Player p", Player.class).getResultList().stream()
                .filter(p -> !AccountDeletionService.DELETED_PLAYER_ID.equals(p.getId()))
                .toList();
        List<Battle> battles = em.createQuery("SELECT b FROM Battle b", Battle.class).getResultList();
        List<HotspotCheckin> checkins = em.createQuery("SELECT c FROM HotspotCheckin c", HotspotCheckin.class).getResultList();
        List<PlayerActivity> activity = em.createQuery("SELECT a FROM PlayerActivity a", PlayerActivity.class).getResultList();

        // Wer war an welchem Tag aktiv: Aktivitäts-Einträge + Battles + Check-ins (für die Zeit vor der Aktivitäts-Tabelle)
        Map<LocalDate, Set<String>> activeByDay = new HashMap<>();
        activity.forEach(a -> activeByDay.computeIfAbsent(a.getDay(), d -> new HashSet<>()).add(a.getPlayerId()));
        for (Battle b : battles) {
            if (!"DONE".equals(b.getStatus())) continue;
            LocalDate d = day(b.getCreatedAt());
            Set<String> set = activeByDay.computeIfAbsent(d, x -> new HashSet<>());
            set.add(b.getFromPlayer().getId());
            set.add(b.getToPlayer().getId());
        }
        checkins.forEach(c -> activeByDay.computeIfAbsent(c.getDay(), d -> new HashSet<>()).add(c.getPlayerId()));
        players.stream().filter(p -> p.getLastSeenAt() != null)
                .forEach(p -> activeByDay.computeIfAbsent(day(p.getLastSeenAt()), d -> new HashSet<>()).add(p.getId()));

        // Erster Tag pro Spieler: Anlegedatum, sonst erste bekannte Aktivität
        Map<String, LocalDate> firstDay = new HashMap<>();
        activeByDay.forEach((d, ids) -> ids.forEach(id -> firstDay.merge(id, d, (a, b) -> a.isBefore(b) ? a : b)));
        for (Player p : players) {
            if (p.getCreatedAt() != null) firstDay.put(p.getId(), day(p.getCreatedAt()));
        }

        List<DayPoint> daily = new ArrayList<>();
        for (LocalDate d = from; !d.isAfter(today); d = d.plusDays(1)) {
            LocalDate day = d;
            List<Battle> done = battles.stream()
                    .filter(b -> "DONE".equals(b.getStatus()) && day(b.getCreatedAt()).equals(day)).toList();
            daily.add(new DayPoint(day.toString(),
                    activeByDay.getOrDefault(day, Set.of()).stream().filter(firstDay::containsKey).count(),
                    players.stream().filter(p -> day.equals(firstDay.get(p.getId()))).count(),
                    done.stream().filter(b -> mode(b) == BattleMode.RANKED_KNOWLEDGE).count(),
                    done.stream().filter(b -> mode(b) == BattleMode.RANKED_REALLIFE).count(),
                    done.stream().filter(b -> mode(b) == BattleMode.FRIENDLY).count(),
                    checkins.stream().filter(c -> day.equals(c.getDay())).count()));
        }

        List<Battle> inRange = battles.stream().filter(b -> !day(b.getCreatedAt()).isBefore(from)).toList();
        List<Battle> doneInRange = inRange.stream().filter(b -> "DONE".equals(b.getStatus())).toList();

        long[] byHour = new long[24];
        doneInRange.forEach(b -> byHour[zoned(b.getCreatedAt()).getHour()]++);

        Set<String> active7 = new HashSet<>();
        Map<String, Integer> daysActive7 = new HashMap<>();
        for (int i = 0; i < 7; i++) {
            for (String id : activeByDay.getOrDefault(today.minusDays(i), Set.of())) {
                active7.add(id);
                daysActive7.merge(id, 1, Integer::sum);
            }
        }

        Instant now = Instant.now();
        Totals totals = new Totals(
                players.size(),
                activeByDay.getOrDefault(today, Set.of()).size(),
                active7.size(),
                players.stream().filter(p -> firstDay.containsKey(p.getId())
                        && !firstDay.get(p.getId()).isBefore(today.minusDays(6))).count(),
                daysActive7.values().stream().filter(n -> n >= 2).count(),
                battles.stream().filter(b -> "DONE".equals(b.getStatus()) && day(b.getCreatedAt()).equals(today)).count(),
                battles.stream().filter(b -> "DONE".equals(b.getStatus())).count(),
                checkins.stream().filter(c -> today.equals(c.getDay())).count(),
                em.createQuery("SELECT COUNT(r) FROM PlayerReport r WHERE r.status = :s", Long.class)
                        .setParameter("s", PlayerReport.Status.OPEN).getSingleResult(),
                players.stream().filter(p -> p.getBanUntil() != null && p.getBanUntil().isAfter(now)).count());

        List<NamedCount> modes = List.of(
                new NamedCount("Quiz-Show", doneInRange.stream().filter(b -> mode(b) == BattleMode.RANKED_KNOWLEDGE).count()),
                new NamedCount("Real-Life", doneInRange.stream().filter(b -> mode(b) == BattleMode.RANKED_REALLIFE).count()),
                new NamedCount("Friendly", doneInRange.stream().filter(b -> mode(b) == BattleMode.FRIENDLY).count()));

        Map<String, String> outcomeNames = new LinkedHashMap<>();
        outcomeNames.put("DONE", "Gespielt");
        outcomeNames.put("DECLINED", "Abgelehnt");
        outcomeNames.put("CANCELLED", "Zurückgezogen");
        outcomeNames.put("EXPIRED", "Nicht beantwortet");
        outcomeNames.put("ABANDONED", "Abgebrochen");
        List<NamedCount> outcomes = outcomeNames.entrySet().stream()
                .map(e -> new NamedCount(e.getValue(), inRange.stream().filter(b -> e.getKey().equals(b.getStatus())).count()))
                .toList();

        List<Rank> ranks = rankRepository.getAllRanks().stream().sorted(Comparator.comparingInt(Rank::getMin)).toList();
        Map<String, Long> perRank = new LinkedHashMap<>();
        ranks.forEach(r -> perRank.put(r.getName(), 0L));
        players.forEach(p -> {
            Rank r = rankRepository.rankForPoints(p.getTrophies(), ranks);
            if (r != null) perRank.merge(r.getName(), 1L, Long::sum);
        });

        Map<String, Long> perCharacter = players.stream().collect(Collectors.groupingBy(
                p -> CharacterCatalog.find(p.getCharacter() == null ? "junge" : p.getCharacter())
                        .map(CharacterCatalog.Entry::name).orElse("Unbekannt"),
                Collectors.counting()));

        Map<String, Long> perChallenge = doneInRange.stream()
                .filter(b -> mode(b) != BattleMode.RANKED_KNOWLEDGE && b.getChallenge() != null)
                .collect(Collectors.groupingBy(b -> shortName(b.getChallenge().getText()), Collectors.counting()));

        Map<String, long[]> record = new HashMap<>();   // [battles, wins]
        for (Battle b : battles) {
            if (!"DONE".equals(b.getStatus()) || mode(b) == BattleMode.FRIENDLY) continue;
            for (Player p : List.of(b.getFromPlayer(), b.getToPlayer())) {
                long[] r = record.computeIfAbsent(p.getId(), x -> new long[2]);
                r[0]++;
                if (b.getWinner() != null && b.getWinner().getId().equals(p.getId())) r[1]++;
            }
        }
        List<LeaderRow> leaderboard = players.stream()
                .sorted(Comparator.comparingInt(Player::getTrophies).reversed())
                .limit(10)
                .map(p -> {
                    long[] r = record.getOrDefault(p.getId(), new long[2]);
                    Rank rank = rankRepository.rankForPoints(p.getTrophies(), ranks);
                    return new LeaderRow(p.getName(), rank == null ? "–" : rank.getName(), p.getTrophies(), r[0], r[1],
                            p.getLastSeenAt() == null ? null : p.getLastSeenAt().toString());
                })
                .toList();

        return new Stats(now.toString(), days, totals, daily, byHour, modes, outcomes,
                toList(perRank, false), toList(perCharacter, true), toList(perChallenge, true).stream().limit(6).toList(),
                leaderboard);
    }

    private static List<NamedCount> toList(Map<String, Long> map, boolean sortByCount) {
        var stream = map.entrySet().stream().map(e -> new NamedCount(e.getKey(), e.getValue()));
        return sortByCount ? stream.sorted(Comparator.comparingLong(NamedCount::count).reversed()).toList() : stream.toList();
    }

    /** "Sprint-Challenge: Laufe …" → "Sprint-Challenge" */
    static String shortName(String text) {
        if (text == null) return "–";
        int colon = text.indexOf(':');
        String s = colon > 0 ? text.substring(0, colon) : text;
        return s.length() > 40 ? s.substring(0, 39) + "…" : s;
    }

    private static BattleMode mode(Battle b) {
        return BattleMode.from(b.getType());
    }

    private static ZonedDateTime zoned(LocalDateTime t) {
        return t.atZone(SERVER_ZONE).withZoneSameInstant(ZONE);
    }

    private static LocalDate day(LocalDateTime t) {
        return zoned(t).toLocalDate();
    }

    private static LocalDate day(Instant t) {
        return t.atZone(ZONE).toLocalDate();
    }
}
