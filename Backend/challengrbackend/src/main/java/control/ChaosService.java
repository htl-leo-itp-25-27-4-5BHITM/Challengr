package control;

import entity.Player;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.Optional;
import java.util.Random;

/**
 * Chaos-Stunde: einmal am Tag, zu einer zufälligen Zeit zwischen 14 und 20 Uhr (Wien), gilt eine Stunde lang
 * eine verrückte Regel. Zeit und Regel ergeben sich aus dem Datum – überlebt Neustarts, braucht keine Tabelle.
 */
@ApplicationScoped
public class ChaosService {

    public enum Rule {
        DOUBLE_TROPHIES("Doppelte Trophäen", "Jeder Liga-Sieg bringt doppelt so viele Trophäen."),
        SCREAM_ONLY("Nur Schreien", "Real-Life in der Liga ist eine Stunde lang nur die Schrei-Challenge."),
        MEGA_QUIZ("Mega-Quiz", "Die Quiz-Show hat 6 statt 4 Fragen."),
        GIANTS("Riesen-Stunde", "Alle Figuren auf der Karte sind riesig."),
        STICKER_RAIN("Sticker-Regen", "Jeder Liga-Sieg bringt sicher einen Sticker.");

        public final String title;
        public final String description;

        Rule(String title, String description) {
            this.title = title;
            this.description = description;
        }
    }

    public record Window(LocalDate day, Instant start, Instant end, Rule rule) {
        public boolean contains(Instant t) {
            return !t.isBefore(start) && t.isBefore(end);
        }
    }

    static final Duration LENGTH = Duration.ofHours(1);
    /** Push nur an Spieler, die in dieser Zeit aktiv waren */
    static final Duration PUSH_RECENT = Duration.ofDays(7);

    /** Nur für Tests: erzwingt eine Regel (null = normal nach Datum) */
    public static volatile Rule override;

    private volatile LocalDate pushedFor;

    @Inject
    EntityManager em;

    @Inject
    PushService push;

    /** Zeitfenster eines Tages: Start zwischen 14:00 und 19:00, eine Stunde lang. */
    public static Window windowFor(LocalDate day) {
        Random r = new Random(day.toEpochDay() * 7919L + 17);
        int startMinute = 14 * 60 + r.nextInt(5 * 60);
        ZonedDateTime start = day.atStartOfDay(ActivityTracker.ZONE).plusMinutes(startMinute);
        Rule rule = Rule.values()[r.nextInt(Rule.values().length)];
        return new Window(day, start.toInstant(), start.plus(LENGTH).toInstant(), rule);
    }

    /** Laufende Chaos-Stunde (mit Regel), sonst leer. */
    public Optional<Window> current() {
        Instant now = Instant.now();
        if (override != null) {
            return Optional.of(new Window(LocalDate.now(ActivityTracker.ZONE), now.minusSeconds(60), now.plus(LENGTH), override));
        }
        Window w = windowFor(LocalDate.now(ActivityTracker.ZONE));
        return w.contains(now) ? Optional.of(w) : Optional.empty();
    }

    public boolean active(Rule rule) {
        return current().map(w -> w.rule() == rule).orElse(false);
    }

    /** Beim Start einmal alle aktiven Spieler per Push wecken. */
    @Scheduled(every = "60s", delayed = "30s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    @Transactional
    void announce() {
        if (override != null) return;
        Optional<Window> w = current();
        if (w.isEmpty() || w.get().day().equals(pushedFor)) return;
        pushedFor = w.get().day();
        Instant since = Instant.now().minus(PUSH_RECENT);
        for (Player p : em.createQuery("SELECT p FROM Player p WHERE p.lastSeenAt > :since", Player.class)
                .setParameter("since", since).getResultList()) {
            if (PracticeBot.is(p.getId())) continue;
            push.chaos(p.getId(), w.get().rule());
        }
    }
}
