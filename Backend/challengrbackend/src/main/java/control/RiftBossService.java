package control;

import boundary.GameSocket;
import com.fasterxml.jackson.databind.ObjectMapper;
import entity.Challenges;
import entity.CustomSpot;
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
    public static final int MAX_HP = 6000;
    /** Schaden pro Treffer-Einheit (Tippen/Schütteln) */
    public static final int DAMAGE_PER_UNIT = 3;
    /** Höchstens so viel Tipp-/Schüttel-Schaden pro Spieler und Sekunde */
    public static final int MAX_DPS = 20;
    /** Heilung nur zur Strafe: pro Kämpfer, der dem Riss-Schlag nicht ausweicht */
    public static final int SLAM_HEAL = 150;
    /** Schwachstelle rechtzeitig getroffen (kritischer Treffer, pro Spieler einmal) */
    public static final int WEAKSPOT_DAMAGE = 120;
    /** Riss-Frage richtig beantwortet / falsch beantwortet (heilt ihn) */
    public static final int QUESTION_DAMAGE = 200;
    public static final int QUESTION_HEAL = 100;
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
    public static volatile Duration weakspotEvery = Duration.ofSeconds(10);
    public static volatile Duration weakspotWindow = Duration.ofMillis(2000);
    public static volatile Duration questionEvery = Duration.ofSeconds(30);
    public static volatile Duration questionWindow = Duration.ofSeconds(8);

    /** Riss-Frage: Wissensfrage aus dem Quiz-Pool */
    record Question(long id, String text, List<String> options, int correct) {}

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
        // Schwachstelle
        long weakId;
        Instant weakDeadline, nextWeakAt;
        final Set<String> weakHit = ConcurrentHashMap.newKeySet();
        // Riss-Frage
        Question question;
        Instant questionDeadline, nextQuestionAt;
        final Set<String> answered = ConcurrentHashMap.newKeySet();

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

    @Inject
    ChallengeRepository challenges;

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
                b.nextWeakAt = now.plusSeconds(5);
                b.nextQuestionAt = now.plusSeconds(20);
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

    /** Schwachstelle getroffen – nur die aktuelle, rechtzeitig und einmal pro Spieler. */
    public void crit(long bossId, String playerId, long spotId) {
        Boss b = bosses.get(bossId);
        if (b == null) return;
        boolean finished;
        int dmg;
        synchronized (b) {
            Instant now = Instant.now();
            if (!b.fighters.contains(playerId) || (b.phase != Phase.FIGHT && b.phase != Phase.RAGE)
                    || spotId != b.weakId || b.weakDeadline == null || now.isAfter(b.weakDeadline) || !b.weakHit.add(playerId)) return;
            dmg = WEAKSPOT_DAMAGE;
            Instant debuff = b.debuffUntil.get(playerId);
            if (debuff != null && debuff.isAfter(now)) dmg /= 2;
            b.hp = Math.max(0, b.hp - dmg);
            b.damage.merge(playerId, dmg, Integer::sum);
            finished = updatePhase(b, now);
        }
        send(playerId, Map.of("type", "boss-crit", "bossId", b.id, "spotId", spotId, "damage", dmg));
        if (finished) end(b); else broadcastState(b);
    }

    /** Antwort auf die Riss-Frage: richtig = Schaden, falsch = er heilt sich. Einmal pro Spieler. */
    public void answer(long bossId, String playerId, long questionId, int index) {
        Boss b = bosses.get(bossId);
        if (b == null) return;
        boolean finished, correct;
        int correctIndex;
        synchronized (b) {
            Instant now = Instant.now();
            Question q = b.question;
            if (!b.fighters.contains(playerId) || q == null || q.id() != questionId || b.questionDeadline == null
                    || now.isAfter(b.questionDeadline) || !b.answered.add(playerId)) return;
            correct = index == q.correct();
            correctIndex = q.correct();
            if (correct) {
                b.hp = Math.max(0, b.hp - QUESTION_DAMAGE);
                b.damage.merge(playerId, QUESTION_DAMAGE, Integer::sum);
            } else {
                b.hp = Math.min(MAX_HP, b.hp + QUESTION_HEAL);
            }
            finished = updatePhase(b, now);
        }
        send(playerId, Map.of("type", "boss-answer-result", "bossId", b.id, "questionId", questionId,
                "correct", correct, "correctIndex", correctIndex, "damage", correct ? QUESTION_DAMAGE : -QUESTION_HEAL));
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
                    // keine Heilung von selbst – nur als Strafe (Riss-Schlag nicht ausgewichen, falsche Riss-Frage)
                    if (b.nextWeakAt != null && !now.isBefore(b.nextWeakAt)) {
                        b.weakId++;
                        b.weakHit.clear();
                        b.weakDeadline = now.plus(weakspotWindow);
                        b.nextWeakAt = now.plus(weakspotEvery);
                        // Position auf dem Boss (0…1), nicht ganz am Rand
                        sendAll(b, Map.of("type", "boss-weakspot", "bossId", b.id, "spotId", b.weakId,
                                "x", 0.25 + random.nextDouble() * 0.5, "y", 0.2 + random.nextDouble() * 0.55,
                                "ms", weakspotWindow.toMillis()));
                    }
                    if (b.nextQuestionAt != null && !now.isBefore(b.nextQuestionAt)) {
                        b.nextQuestionAt = now.plus(questionEvery);
                        Question q = randomQuestion();
                        if (q != null) {
                            b.question = q;
                            b.answered.clear();
                            b.questionDeadline = now.plus(questionWindow);
                            sendAll(b, Map.of("type", "boss-question", "bossId", b.id, "questionId", q.id(), "text", q.text(),
                                    "options", q.options(), "ms", questionWindow.toMillis()));
                        }
                    }
                    if (b.phase == Phase.RAGE) {
                        if (b.slamDeadline != null && !now.isBefore(b.slamDeadline)) {
                            // wer nicht ausgewichen ist: halber Schaden für eine Weile, der Boss heilt sich
                            for (String f : b.fighters) {
                                if (!b.dodged.contains(f)) {
                                    b.debuffUntil.put(f, now.plus(debuffTime));
                                    b.hp = Math.min(MAX_HP, b.hp + SLAM_HEAL);
                                    changed = true;
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

    /** Zufällige Wissensfrage mit vier Antworten (wie in der Quiz-Show) */
    Question randomQuestion() {
        try {
            return QuarkusTransaction.requiringNew().call(() -> {
                List<Challenges> pool = challenges.findChallengesByKat(BattleMode.KNOWLEDGE_CATEGORY).stream()
                        .filter(c -> c.getCorrectIndex() != null && c.getOptionA() != null)
                        .toList();
                if (pool.isEmpty()) return null;
                Challenges c = pool.get(random.nextInt(pool.size()));
                return new Question(c.getId(), c.getText(),
                        List.of(c.getOptionA(), c.getOptionB(), c.getOptionC(), c.getOptionD()), c.getCorrectIndex());
            });
        } catch (Exception e) {
            System.out.println("Riss-Frage nicht geladen: " + e.getMessage());
            return null;
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

    /** Alle offenen Risse (Dashboard) */
    public List<View> all() {
        return bosses.values().stream()
                .filter(b -> b.phase().ordinal() < Phase.DEFEATED.ordinal())
                .sorted(Comparator.comparingLong(b -> b.id))
                .map(this::view)
                .toList();
    }

    /**
     * Dashboard: Riss beim Spieler öffnen – am nächsten öffentlichen Ort (Check-in-Ort),
     * sonst ein paar Meter neben seiner Position.
     */
    public Boss spawnNear(Player p) {
        // zuerst ein temporärer Riss-Checkpoint in der Nähe, dann der nächste öffentliche Ort
        Optional<CustomSpot> checkpoint = em.createQuery(
                        "SELECT c FROM CustomSpot c WHERE c.active = true AND c.expiresAt IS NOT NULL", CustomSpot.class)
                .getResultStream()
                .filter(CustomSpot::isLive)
                .filter(c -> HotspotCatalog.distanceMeters(p.getLatitude(), p.getLongitude(), c.getLatitude(), c.getLongitude()) <= 300)
                .findFirst();
        if (checkpoint.isPresent()) {
            return spawn(checkpoint.get().getName(), checkpoint.get().getLatitude(), checkpoint.get().getLongitude());
        }
        Optional<Landmark> place = landmarks.near(p.getLatitude(), p.getLongitude()).stream().findFirst();
        // ohne Ort: gerundet wie bei "nearby" und ohne Namen – verrät nicht, wo genau jemand ist
        return place.map(l -> spawn(l.getName(), l.getLatitude(), l.getLongitude()))
                .orElseGet(() -> spawn(CHECKPOINT_NAME, LocationPrivacy.coarse(p.getLatitude()), LocationPrivacy.coarse(p.getLongitude())));
    }

    public static final String CHECKPOINT_NAME = "Riss-Punkt";
    public static final Duration CHECKPOINT_LIFETIME = Duration.ofMinutes(30);

    /**
     * Dashboard: temporärer Check-in-Punkt beim Spieler (30 Minuten), damit der Riss genau dort erscheinen kann.
     * Neutraler Name und gerundete Position – niemand erfährt daraus, wo genau der Spieler ist.
     */
    public CustomSpot createCheckpoint(Player p) {
        CustomSpot c = new CustomSpot();
        c.setId("riss-" + Long.toString(System.currentTimeMillis(), 36));
        c.setName(CHECKPOINT_NAME);
        c.setLatitude(LocationPrivacy.coarse(p.getLatitude()));
        c.setLongitude(LocationPrivacy.coarse(p.getLongitude()));
        c.setRadiusMeters(80);
        c.setPoints(5);
        c.setBonus(5);
        c.setExpiresAt(Instant.now().plus(CHECKPOINT_LIFETIME));
        em.persist(c);
        return c;
    }

    /** Laufende temporäre Checkpoints (Dashboard) */
    public List<CustomSpot> checkpoints() {
        return em.createQuery("SELECT c FROM CustomSpot c WHERE c.active = true AND c.expiresAt IS NOT NULL", CustomSpot.class)
                .getResultStream().filter(CustomSpot::isLive).sorted(Comparator.comparing(CustomSpot::getExpiresAt)).toList();
    }

    /** Dashboard: Riss schließen – Kämpfer erfahren es wie bei einer Flucht. */
    public boolean close(long bossId) {
        Boss b = bosses.remove(bossId);
        if (b == null) return false;
        synchronized (b) {
            b.endedAt = Instant.now();
            b.phase = Phase.ESCAPED;
        }
        sendAll(b, Map.of("type", "boss-end", "bossId", b.id, "result", "ESCAPED"));
        return true;
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
