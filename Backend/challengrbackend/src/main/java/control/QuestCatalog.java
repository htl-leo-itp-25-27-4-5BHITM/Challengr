package control;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Random;

/**
 * Tagesaufgaben (bringen Challengr Coins) und Events (zeitlich begrenzte Challenges mit Figur als Belohnung).
 * Events kommen aus der Datenbank ({@link QuestEventStore}, im Dashboard gepflegt) – die App braucht kein Update.
 */
public final class QuestCatalog {

    /** Was gezählt wird – alles aus vorhandenen Spieldaten berechnet. */
    public enum Metric {
        /** an diesem Tag/im Zeitraum aktiv gewesen (Spieltage) */
        ACTIVE_DAYS,
        /** fertige Battles, egal welcher Modus */
        BATTLES,
        /** gewonnene Liga-Battles */
        LEAGUE_WINS,
        /** Quiz-Shows (Liga Wissen) */
        QUIZ_SHOWS,
        /** Real-Life-Challenges (Liga) */
        REALLIFE,
        /** Friendlys */
        FRIENDLIES,
        /** Battles gegen Freunde */
        FRIEND_BATTLES,
        /** Hotspot-Check-ins */
        CHECKINS,
        /** Anzahl Freunde (aktueller Stand, nicht zeitgebunden) */
        FRIENDS,
        /** abgeholte Tagesaufgaben */
        DAILY_QUESTS
    }

    public record Task(String id, String title, String icon, Metric metric, int target, int coins) {}

    public record Event(String id, String title, String subtitle, LocalDate start, LocalDate end,
                        String rewardCharacter, int rewardCoins, List<Task> tasks) {
        public boolean isActive(LocalDate day) {
            return !day.isBefore(start) && !day.isAfter(end);
        }
    }

    /** Immer die erste Tagesaufgabe: einfach vorbeischauen. */
    public static final Task VISIT = new Task("VISIT", "Schau heute bei Challengr vorbei", "hand.wave.fill", Metric.ACTIVE_DAYS, 1, 10);

    /** Daraus werden jeden Tag zwei Aufgaben gelost (für alle gleich – man kann sich in der Pause austauschen). */
    public static final List<Task> DAILY_POOL = List.of(
            new Task("PLAY_2", "Spiele 2 Battles", "bolt.fill", Metric.BATTLES, 2, 20),
            new Task("WIN_1", "Gewinne 1 Liga-Battle", "trophy.fill", Metric.LEAGUE_WINS, 1, 30),
            new Task("QUIZ_1", "Spiele 1 Quiz-Show", "brain.head.profile", Metric.QUIZ_SHOWS, 1, 20),
            new Task("REALLIFE_1", "Spiele 1 Real-Life-Challenge", "figure.run", Metric.REALLIFE, 1, 20),
            new Task("FRIENDLY_1", "Spiele 1 Friendly", "hand.thumbsup.fill", Metric.FRIENDLIES, 1, 15),
            new Task("FRIEND_1", "Fordere einen Freund heraus", "person.2.fill", Metric.FRIEND_BATTLES, 1, 25),
            new Task("CHECKIN_1", "Check am Hotspot ein", "mappin.and.ellipse", Metric.CHECKINS, 1, 25)
    );

    /** Startinhalt der Event-Tabelle (beim ersten Start angelegt, danach im Dashboard gepflegt). */
    public static final Event BETA =
            new Event("beta", "Beta-Event: Crash-Test", "Nur in der Testphase – danach nie wieder!",
                    LocalDate.of(2026, 10, 13), LocalDate.of(2026, 11, 30), "crash-dummy", 100,
                    List.of(
                            new Task("DAYS_5", "Spiele an 5 verschiedenen Tagen", "calendar", Metric.ACTIVE_DAYS, 5, 0),
                            new Task("BATTLES_10", "Spiele 10 Battles", "bolt.fill", Metric.BATTLES, 10, 0),
                            new Task("QUIZ_3", "Spiele 3 Quiz-Shows", "brain.head.profile", Metric.QUIZ_SHOWS, 3, 0),
                            new Task("CHECKINS_2", "Check 2× am Hotspot ein", "mappin.and.ellipse", Metric.CHECKINS, 2, 0),
                            new Task("FRIENDS_1", "Finde mindestens 1 Freund", "person.badge.plus", Metric.FRIENDS, 1, 0),
                            new Task("DAILY_6", "Erledige 6 Tagesaufgaben", "checklist", Metric.DAILY_QUESTS, 6, 0)
                    ));

    /** Symbol in der App je Messgröße (für im Dashboard angelegte Aufgaben). */
    public static String iconFor(Metric m) {
        return switch (m) {
            case ACTIVE_DAYS -> "calendar";
            case BATTLES -> "bolt.fill";
            case LEAGUE_WINS -> "trophy.fill";
            case QUIZ_SHOWS -> "brain.head.profile";
            case REALLIFE -> "figure.run";
            case FRIENDLIES -> "hand.thumbsup.fill";
            case FRIEND_BATTLES -> "person.2.fill";
            case CHECKINS -> "mappin.and.ellipse";
            case FRIENDS -> "person.badge.plus";
            case DAILY_QUESTS -> "checklist";
        };
    }

    private QuestCatalog() {}

    /** Die drei Aufgaben eines Tages: Vorbeischauen + zwei gelost (gleiches Datum = gleiche Aufgaben). */
    public static List<Task> dailyFor(LocalDate day) {
        List<Task> pool = new ArrayList<>(DAILY_POOL);
        java.util.Collections.shuffle(pool, new Random(day.toEpochDay() * 7919L));
        return List.of(VISIT, pool.get(0), pool.get(1));
    }

    public static String dailyKey(LocalDate day, Task task) {
        return "daily:" + day + ":" + task.id();
    }

    public static String eventKey(String eventId) {
        return "event:" + eventId;
    }
}
