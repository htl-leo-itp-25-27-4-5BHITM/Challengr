package control;

import boundary.GameSocket;
import com.fasterxml.jackson.databind.ObjectMapper;
import entity.Landmark;
import entity.Player;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Riss-Wächter – übermächtiger Co-op-Boss.
 * Taucht ab und zu an einem öffentlichen Ort (Check-in-Punkt aus OpenStreetMap) auf, wenn mindestens zwei Spieler
 * in der Gegend aktiv sind, und bleibt 30 Minuten. Der Kampf startet, sobald zwei Spieler beigetreten sind, und dauert
 * 3 Minuten. Allein ist er nicht zu schaffen: er heilt sich schneller, als ein Spieler Schaden machen kann.
 * Phasen: Angriff → Raserei (ab 50 %, regelmäßig ein Riss-Schlag, dem man ausweichen muss) → Finale (ab 10 %,
 * alle müssen gleichzeitig schreien – mindestens zwei laut genug, sonst brüllt er zurück).
 * Alles im Speicher: nach einem Neustart ist ein laufender Boss weg (er kommt wieder).
 */
@ApplicationScoped
public class RiftBossService {

    public enum Phase { WAITING, FIGHT, RAGE, FINALE, DEFEATED, ESCAPED }

    public static final String NAME = "Riss-Wächter";
    public static final int MAX_HP = 5000;
    /** Heilung pro Sekunde während des Kampfs (nicht im Finale) */
    public static final int HEAL_PER_SECOND = 12;
    /** Schaden pro Treffer-Einheit (Tippen/Schütteln) */
    public static final int DAMAGE_PER_UNIT = 3;
    /** Höchstens so viel Schaden pro Spieler und Sekunde – allein bleibt man unter der Heilung + Zeit */
    public static final int MAX_DPS = 36;
    public static final int MIN_FIGHTERS = 2;
    /** Wie nah man am Boss sein muss, um beizutreten */
    public static final double JOIN_RADIUS_M = 250;
    public static final int SHARDS_BASE = 10;
    public static final int COINS = 50;
    /** Finale: Schrei ab so viel dB (SoundMeter, -60…0) zählt als "laut genug" */
    public static final double SCREAM_THRESHOLD_DB = -25;

    // Zeiten – für Tests verkürzbar
    public static volatile Duration lifetime = Duration.ofMinutes(30);
    public static volatile Duration fightTime = Duration.ofMinutes(3);
    public static volatile Duration slamEvery = Duration.ofSeconds(15);
    public static volatile Duration slamWindow = Duration.ofMillis(1500);
    public static volatile Duration finaleWindow = Duration.ofSeconds(6);
    public static volatile Duration debuffTime = Duration.ofSeconds(10);

    public static final class Boss {
        public final long id;
        public final String place;
        public final double latitude, longitude;
        public final Instant spawnedAt, expiresAt;
        int hp = MAX_HP;
        Phase phase = Phase.WAITING;
        Instant fightEndsAt;
        Instant nextSlamAt;
        Instant slamDeadline;
        Instant finaleDeadline;
        final Set<String> fighters = ConcurrentHashMap.newKeySet();
        final Set<String> dodged = ConcurrentHashMap.newKeySet();
        final Map<String, Double> screams = new ConcurrentHashMap<>();
        final Map<String, Integer> damage = new ConcurrentHashMap<>();
        final Map<String, long[]> dpsWindow = new ConcurrentHashMap<>();   // [Sekunde, Schaden in dieser Sekunde]
        final Map<String, Instant> debuffUntil = new ConcurrentHashMap<>();
        Instant endedAt;

        Boss(long id, String place, double latitude, double longitude, Instant now) {
            this.id = id;
            this.place = place;
            this.latitude = latitude;
            this.longitude = longitude;
            this.spawnedAt = now;
            this.expiresAt = now.plus(lifetime);
        }

        public synchronized int hp() { return hp; }
        public synchronized Phase phase() { return phase; }
        public Set<String> fighters() { return Set.copyOf(fighters); }
    }

    /** Für die App: Boss in der Nähe */
    public record View(long id, String name, String place, double latitude, double longitude, int hp, int maxHp,
                       String phase, int fighters, int minFighters, String expiresAt, String fightEndsAt) {}

    private final Map<Long, Boss> bosses = new ConcurrentHashMap<>();
    private final AtomicLong ids = new AtomicLong(1);
    private final ObjectMapper json = new ObjectMapper();
    private final Random random = new Random();

    @Inject
    EntityManager em;

    @Inject
    LandmarkService landmarks;

    // ---------------------------------------------------------
    // Auftauchen
    // ---------------------------------------------------------

    /** Zwischen 15 und 20 Uhr alle 5 Minuten: mit etwas Glück ein neuer Riss bei aktiven Spielern. */
    @Scheduled(every = "5m", delayed = "2m", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void maybeSpawn() {
        LocalTime t = LocalTime.now(ActivityTracker.ZONE);
        if (t.isBefore(LocalTime.of(15, 0)) || t.isAfter(LocalTime.of(20, 0))) return;
        if (activeCount() >= 3 || random.nextInt(100) >= 25) return;
        QuarkusTransaction.requiringNew().run(this::spawnNearActivePlayers);
    }

    /** Spieler, der gerade aktiv ist und mindestens einen weiteren aktiven Spieler im Umkreis von 1 km hat → Riss am nächsten Ort. */
    void spawnNearActivePlayers() {
        Instant since = Instant.now().minus(Duration.ofMinutes(10));
        List<Player> active = em.createQuery("""
                        SELECT p FROM Player p WHERE p.lastSeenAt > :since AND p.invisible = false
                        AND p.latitude IS NOT NULL AND p.longitude IS NOT NULL""", Player.class)
                .setParameter("since", since).getResultList().stream()
                .filter(p -> !PracticeBot.is(p.getId()))
                .toList();
        List<Player> shuffled = new ArrayList<>(active);
        Collections.shuffle(shuffled, random);
        for (Player p : shuffled) {
            boolean company = active.stream().anyMatch(o -> o != p
                    && HotspotCatalog.distanceMeters(p.getLatitude(), p.getLongitude(), o.getLatitude(), o.getLongitude()) <= 1000);
            if (!company) continue;
            Optional<Landmark> place = landmarks.near(p.getLatitude(), p.getLongitude()).stream()
                    .filter(l -> bosses.values().stream().noneMatch(b -> HotspotCatalog.distanceMeters(b.latitude, b.longitude, l.getLatitude(), l.getLongitude()) < 2000))
                    .findFirst();
            if (place.isPresent()) {
                spawn(place.get().getName(), place.get().getLatitude(), place.get().getLongitude());
                return;
            }
        }
    }

    public Boss spawn(String place, double latitude, double longitude) {
        Boss b = new Boss(ids.getAndIncrement(), place, latitude, longitude, Instant.now());
        bosses.put(b.id, b);
        System.out.printf("Riss-Wächter %d erscheint bei %s%n", b.id, place);
        return b;
    }

    public Optional<Boss> find(long id) {
        return Optional.ofNullable(bosses.get(id));
    }

    int activeCount() {
        return (int) bosses.values().stream().filter(b -> b.phase().ordinal() < Phase.DEFEATED.ordinal()).count();
    }

    public List<View> near(double latitude, double longitude, double radiusM) {
        return bosses.values().stream()
                .filter(b -> b.phase().ordinal() < Phase.DEFEATED.ordinal())
                .filter(b -> HotspotCatalog.distanceMeters(latitude, longitude, b.latitude, b.longitude) <= radiusM)
                .map(this::view)
                .toList();
    }

    View view(Boss b) {
        synchronized (b) {
            return new View(b.id, NAME, b.place, b.latitude, b.longitude, b.hp, MAX_HP, b.phase.name(), b.fighters.size(),
                    MIN_FIGHTERS, b.expiresAt.toString(), b.fightEndsAt == null ? null : b.fightEndsAt.toString());
        }
    }

    // ---------------------------------------------------------
    // Kampf
    // ---------------------------------------------------------

    /** Beitreten – nur in der Nähe des Bosses. Der zweite Kämpfer startet den Kampf. */
    public String join(long bossId, String playerId, double playerLat, double playerLon) {
        Boss b = bosses.get(bossId);
        if (b == null) return "Der Riss hat sich geschlossen";
        if (HotspotCatalog.distanceMeters(playerLat, playerLon, b.latitude, b.longitude) > JOIN_RADIUS_M) {
            return "Du bist zu weit weg – geh näher an den Riss";
        }
        synchronized (b) {
            if (b.phase.ordinal() >= Phase.DEFEATED.ordinal()) return "Der Kampf ist vorbei";
            b.fighters.add(playerId);
            if (b.phase == Phase.WAITING && b.fighters.size() >= MIN_FIGHTERS) {
                Instant now = Instant.now();
                b.phase = Phase.FIGHT;
                b.fightEndsAt = now.plus(fightTime);
            }
        }
        broadcastState(b);
        return null;
    }

    /** Treffer: units = Tipper/Schüttler seit dem letzten Paket. Schaden gedeckelt pro Sekunde. */
    public void hit(long bossId, String playerId, int units) {
        Boss b = bosses.get(bossId);
        if (b == null || units <= 0) return;
        boolean finished;
        synchronized (b) {
            if (!b.fighters.contains(playerId) || (b.phase != Phase.FIGHT && b.phase != Phase.RAGE)) return;
            long second = Instant.now().getEpochSecond();
            long[] w = b.dpsWindow.computeIfAbsent(playerId, k -> new long[]{second, 0});
            if (w[0] != second) { w[0] = second; w[1] = 0; }
            int dmg = Math.min(units * DAMAGE_PER_UNIT, (int) (MAX_DPS - w[1]));
            Instant debuff = b.debuffUntil.get(playerId);
            if (debuff != null && debuff.isAfter(Instant.now())) dmg /= 2;
            if (dmg <= 0) return;
            w[1] += dmg;
            b.hp = Math.max(0, b.hp - dmg);
            b.damage.merge(playerId, dmg, Integer::sum);
            finished = updatePhase(b, Instant.now());
        }
        if (finished) end(b); else broadcastState(b);
    }

    public void dodge(long bossId, String playerId) {
        Boss b = bosses.get(bossId);
        if (b == null) return;
        synchronized (b) {
            if (b.slamDeadline != null && Instant.now().isBefore(b.slamDeadline)) b.dodged.add(playerId);
        }
    }

    public void scream(long bossId, String playerId, double db) {
        Boss b = bosses.get(bossId);
        if (b == null) return;
        synchronized (b) {
            if (b.phase == Phase.FINALE && b.fighters.contains(playerId)) b.screams.merge(playerId, db, Math::max);
        }
    }

    /** Phase nach dem Lebensstand – gibt true zurück, wenn der Kampf vorbei ist. Aufruf mit Lock auf b. */
    private boolean updatePhase(Boss b, Instant now) {
        if (b.phase == Phase.FIGHT && b.hp <= MAX_HP / 2) {
            b.phase = Phase.RAGE;
            b.nextSlamAt = now.plus(Duration.ofSeconds(3));
            sendAll(b, Map.of("type", "boss-phase", "bossId", b.id, "phase", "RAGE"));
        }
        if (b.phase == Phase.RAGE && b.hp <= MAX_HP / 10) {
            b.phase = Phase.FINALE;
            b.slamDeadline = null;
            b.screams.clear();
            b.finaleDeadline = now.plus(finaleWindow);
            sendAll(b, Map.of("type", "boss-finale", "bossId", b.id, "seconds", finaleWindow.toMillis() / 1000.0));
        }
        return b.hp <= 0;
    }

    @Scheduled(every = "1s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
    void scheduledTick() {
        tick(Instant.now());
    }

    /** Eine Sekunde Kampf: heilen, Riss-Schläge, Finale auswerten, Zeit abgelaufen, alte Bosse wegräumen. */
    public void tick(Instant now) {
        for (Boss b : List.copyOf(bosses.values())) {
            boolean defeated = false, escaped = false, changed = false;
            synchronized (b) {
                if (b.endedAt != null) {
                    if (b.endedAt.plusSeconds(30).isBefore(now)) bosses.remove(b.id);
                    continue;
                }
                if (b.phase == Phase.WAITING) {
                    if (b.expiresAt.isBefore(now)) { bosses.remove(b.id); }
                    continue;
                }
                if (b.fightEndsAt.isBefore(now) && b.phase != Phase.FINALE) {
                    escaped = true;
                } else if (b.phase == Phase.FIGHT || b.phase == Phase.RAGE) {
                    b.hp = Math.min(MAX_HP, b.hp + HEAL_PER_SECOND);
                    changed = true;
                    if (b.phase == Phase.RAGE) {
                        if (b.slamDeadline != null && !now.isBefore(b.slamDeadline)) {
                            // wer nicht ausgewichen ist: halber Schaden für eine Weile, der Boss heilt sich
                            for (String f : b.fighters) {
                                if (!b.dodged.contains(f)) {
                                    b.debuffUntil.put(f, now.plus(debuffTime));
                                    b.hp = Math.min(MAX_HP, b.hp + 80);
                                }
                            }
                            b.slamDeadline = null;
                        }
                        if (b.slamDeadline == null && b.nextSlamAt != null && !now.isBefore(b.nextSlamAt)) {
                            b.dodged.clear();
                            b.slamDeadline = now.plus(slamWindow);
                            b.nextSlamAt = now.plus(slamEvery);
                            sendAll(b, Map.of("type", "boss-slam", "bossId", b.id, "ms", slamWindow.toMillis()));
                        }
                    }
                } else if (b.phase == Phase.FINALE && b.finaleDeadline != null && !now.isBefore(b.finaleDeadline)) {
                    long loud = b.screams.values().stream().filter(db -> db >= SCREAM_THRESHOLD_DB).count();
                    if (loud >= MIN_FIGHTERS) {
                        b.hp = 0;
                        defeated = true;
                    } else {
                        // nicht gemeinsam laut genug: er brüllt zurück und heilt sich auf ein Viertel
                        b.hp = MAX_HP / 4;
                        b.phase = Phase.RAGE;
                        b.finaleDeadline = null;
                        b.nextSlamAt = now.plusSeconds(3);
                        sendAll(b, Map.of("type", "boss-phase", "bossId", b.id, "phase", "RAGE", "roar", true));
                    }
                    changed = true;
                }
            }
            if (defeated) end(b);
            else if (escaped) escape(b);
            else if (changed) broadcastState(b);
        }
    }

    // ---------------------------------------------------------
    // Ende und Belohnung
    // ---------------------------------------------------------

    private void end(Boss b) {
        Map<String, Integer> damage;
        synchronized (b) {
            if (b.endedAt != null) return;
            b.endedAt = Instant.now();
            b.phase = Phase.DEFEATED;
            damage = Map.copyOf(b.damage);
        }
        int total = Math.max(1, damage.values().stream().mapToInt(Integer::intValue).sum());
        for (String f : b.fighters()) {
            // Grundbelohnung + Anteil am Schaden
            int shards = SHARDS_BASE + (int) Math.round(10.0 * damage.getOrDefault(f, 0) / total);
            QuarkusTransaction.requiringNew().run(() -> {
                Player p = em.find(Player.class, f);
                if (p == null) return;
                p.setRiftShards(p.getRiftShards() + shards);
                p.setPoints(p.getPoints() + COINS);
            });
            send(f, Map.of("type", "boss-end", "bossId", b.id, "result", "DEFEATED", "shards", shards, "coins", COINS,
                    "damage", damage.getOrDefault(f, 0)));
        }
        System.out.printf("Riss-Wächter %d besiegt von %s%n", b.id, b.fighters());
    }

    private void escape(Boss b) {
        synchronized (b) {
            if (b.endedAt != null) return;
            b.endedAt = Instant.now();
            b.phase = Phase.ESCAPED;
        }
        sendAll(b, Map.of("type", "boss-end", "bossId", b.id, "result", "ESCAPED"));
    }

    // ---------------------------------------------------------
    // Nachrichten
    // ---------------------------------------------------------

    private void broadcastState(Boss b) {
        View v = view(b);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("type", "boss-state");
        m.put("bossId", v.id());
        m.put("hp", v.hp());
        m.put("maxHp", v.maxHp());
        m.put("phase", v.phase());
        m.put("fighters", v.fighters());
        m.put("minFighters", v.minFighters());
        if (v.fightEndsAt() != null) m.put("fightEndsAt", v.fightEndsAt());
        sendAll(b, m);
    }

    private void sendAll(Boss b, Map<String, ?> message) {
        for (String f : b.fighters) send(f, message);
    }

    private void send(String playerId, Map<String, ?> message) {
        try {
            GameSocket.sendToPlayerStatic(playerId, json.writeValueAsString(message));
        } catch (Exception e) {
            System.out.println("Boss-Nachricht fehlgeschlagen: " + e.getMessage());
        }
    }

    /** Nur für Tests */
    public void clear() {
        bosses.clear();
    }

    /** Nur für Tests: Lebenspunkte setzen und Phase nachziehen */
    public void setHp(long bossId, int hp) {
        Boss b = bosses.get(bossId);
        boolean finished;
        synchronized (b) {
            b.hp = hp;
            finished = updatePhase(b, Instant.now());
        }
        if (finished) end(b); else broadcastState(b);
    }
}
