package boundary;

import control.AdminAudit;
import control.CharacterCatalog;
import control.QuestCatalog;
import control.QuestCatalog.Event;
import control.QuestCatalog.Metric;
import control.QuestCatalog.Task;
import control.QuestEventStore;
import control.QuestService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/** Events im Dashboard: anlegen, bearbeiten, löschen (nur ohne abgeholte Belohnungen) und Fortschritt der Spieler. */
@Path("/api/admin/events")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("admin")
public class AdminEventResource {

    public record TaskInput(String title, String metric, int target) {}

    public record EventInput(String id, String title, String subtitle, String start, String end,
                             String rewardCharacter, int rewardCoins, List<TaskInput> tasks) {}

    public record EventDTO(Event event, String state, long claimed) {}

    public record Meta(List<Map<String, String>> metrics, List<Map<String, String>> rewardCharacters) {}

    public record TaskProgress(String id, String title, int target, long done) {}

    public record Progress(String eventId, long participants, long completed, long claimed, List<TaskProgress> tasks,
                           String computedAt) {}

    static final Map<Metric, String> LABELS = new EnumMap<>(Map.of(
            Metric.ACTIVE_DAYS, "Spieltage", Metric.BATTLES, "Battles (alle)", Metric.LEAGUE_WINS, "Liga-Siege",
            Metric.QUIZ_SHOWS, "Quiz-Shows", Metric.REALLIFE, "Real-Life-Challenges", Metric.FRIENDLIES, "Friendlys",
            Metric.FRIEND_BATTLES, "Battles gegen Freunde", Metric.CHECKINS, "Check-ins", Metric.FRIENDS, "Freunde",
            Metric.DAILY_QUESTS, "Tagesaufgaben"));

    @Inject
    QuestEventStore store;

    @Inject
    QuestService quests;

    @Inject
    EntityManager em;

    @Inject
    AdminAudit audit;

    private static final Map<String, Progress> PROGRESS_CACHE = new ConcurrentHashMap<>();

    @GET
    @Transactional
    public List<EventDTO> list() {
        LocalDate today = QuestService.today();
        return store.list().stream().map(e -> new EventDTO(e,
                today.isBefore(e.start()) ? "geplant" : today.isAfter(e.end()) ? "beendet" : "läuft", claims(e.id()))).toList();
    }

    @GET
    @Path("/meta")
    public Meta meta() {
        List<Map<String, String>> metrics = Arrays.stream(Metric.values())
                .map(m -> Map.of("id", m.name(), "label", LABELS.get(m))).toList();
        List<Map<String, String>> chars = CharacterCatalog.ALL.stream()
                .filter(c -> c.requirement() == CharacterCatalog.Requirement.EVENT)
                .map(c -> Map.of("id", c.id(), "name", c.name())).toList();
        return new Meta(metrics, chars);
    }

    @POST
    @Transactional
    public Event create(EventInput in) {
        Event e = toEvent(in);
        if (store.find(e.id()).isPresent()) throw new WebApplicationException("Diese ID gibt es schon", 409);
        store.save(e);
        audit.log("EVENT_NEW", null, null, null, e.id() + " " + e.start() + "–" + e.end(), e.title());
        return e;
    }

    @PUT
    @Path("/{id}")
    @Transactional
    public Event update(@PathParam("id") String id, EventInput in) {
        Event old = store.find(id).orElseThrow(() -> new WebApplicationException("Event nicht gefunden", 404));
        Event e = toEvent(new EventInput(id, in.title(), in.subtitle(), in.start(), in.end(), in.rewardCharacter(),
                in.rewardCoins(), in.tasks()));
        store.save(e);
        PROGRESS_CACHE.remove(id);
        audit.log("EVENT_EDIT", null, null, old.start() + "–" + old.end() + ", " + old.tasks().size() + " Challenges",
                e.start() + "–" + e.end() + ", " + e.tasks().size() + " Challenges", e.title());
        return e;
    }

    @DELETE
    @Path("/{id}")
    @Transactional
    public void delete(@PathParam("id") String id) {
        Event e = store.find(id).orElseThrow(() -> new WebApplicationException("Event nicht gefunden", 404));
        if (claims(id) > 0) throw new WebApplicationException("Schon abgeholt – Event kann nicht gelöscht werden (Ende-Datum vorziehen)", 409);
        store.delete(id);
        audit.log("EVENT_DELETE", null, null, e.title(), null, "Event gelöscht");
    }

    /** Fortschritt aller Spieler, die im Event-Zeitraum aktiv waren (1 Minute gemerkt). */
    @GET
    @Path("/{id}/progress")
    @Transactional
    public Progress progress(@PathParam("id") String id, @QueryParam("fresh") boolean fresh) {
        Progress cached = PROGRESS_CACHE.get(id);
        if (!fresh && cached != null && Instant.parse(cached.computedAt()).isAfter(Instant.now().minusSeconds(60))) return cached;
        Event e = store.find(id).orElseThrow(() -> new WebApplicationException("Event nicht gefunden", 404));
        LocalDate to = QuestService.today().isBefore(e.end()) ? QuestService.today() : e.end();
        List<String> players = em.createQuery(
                        "SELECT DISTINCT a.playerId FROM PlayerActivity a WHERE a.day BETWEEN :f AND :t", String.class)
                .setParameter("f", e.start()).setParameter("t", to).getResultList();
        long[] done = new long[e.tasks().size()];
        long completed = 0, claimed = 0;
        for (String p : players) {
            if (em.find(entity.Player.class, p) == null) continue;
            var view = quests.progress(e, p);
            for (int i = 0; i < done.length; i++) if (view.tasks().get(i).done()) done[i]++;
            if (view.completed()) completed++;
            if (view.claimed()) claimed++;
        }
        List<TaskProgress> tasks = new ArrayList<>();
        for (int i = 0; i < done.length; i++) {
            Task t = e.tasks().get(i);
            tasks.add(new TaskProgress(t.id(), t.title(), t.target(), done[i]));
        }
        Progress result = new Progress(id, players.size(), completed, claimed, tasks, Instant.now().toString());
        PROGRESS_CACHE.put(id, result);
        return result;
    }

    private long claims(String eventId) {
        return em.createQuery("SELECT COUNT(c) FROM QuestClaim c WHERE c.questKey = :k", Long.class)
                .setParameter("k", QuestCatalog.eventKey(eventId)).getSingleResult();
    }

    static Event toEvent(EventInput in) {
        if (in == null) throw new WebApplicationException("Leere Anfrage", 400);
        String id = in.id() == null ? "" : in.id().trim().toLowerCase();
        if (!id.matches("[a-z0-9-]{2,32}")) throw new WebApplicationException("ID: 2–32 Zeichen, nur a–z, 0–9 und -", 400);
        String title = in.title() == null ? "" : in.title().trim();
        if (title.length() < 3 || title.length() > 80) throw new WebApplicationException("Titel: 3–80 Zeichen", 400);
        String subtitle = in.subtitle() == null ? "" : in.subtitle().trim();
        if (subtitle.length() > 160) throw new WebApplicationException("Untertitel: höchstens 160 Zeichen", 400);
        LocalDate start, end;
        try {
            start = LocalDate.parse(in.start());
            end = LocalDate.parse(in.end());
        } catch (Exception ex) {
            throw new WebApplicationException("Datum als JJJJ-MM-TT", 400);
        }
        if (end.isBefore(start)) throw new WebApplicationException("Ende liegt vor dem Start", 400);
        if (end.isAfter(start.plusDays(120))) throw new WebApplicationException("Höchstens 120 Tage lang", 400);
        String reward = in.rewardCharacter() == null || in.rewardCharacter().isBlank() ? null : in.rewardCharacter();
        if (reward != null && CharacterCatalog.find(reward).filter(c -> c.requirement() == CharacterCatalog.Requirement.EVENT).isEmpty()) {
            throw new WebApplicationException("Diese Figur kann keine Event-Belohnung sein", 400);
        }
        if (in.rewardCoins() < 0 || in.rewardCoins() > 1000) throw new WebApplicationException("Coins: 0–1000", 400);
        if (reward == null && in.rewardCoins() == 0) throw new WebApplicationException("Belohnung fehlt (Figur oder Coins)", 400);
        if (in.tasks() == null || in.tasks().isEmpty() || in.tasks().size() > 10) throw new WebApplicationException("1–10 Challenges", 400);
        List<Task> tasks = new ArrayList<>();
        for (int i = 0; i < in.tasks().size(); i++) {
            TaskInput t = in.tasks().get(i);
            Metric m;
            try {
                m = Metric.valueOf(t.metric());
            } catch (Exception ex) {
                throw new WebApplicationException("Unbekannte Messgröße bei Challenge " + (i + 1), 400);
            }
            if (t.target() < 1 || t.target() > 1000) throw new WebApplicationException("Ziel 1–1000 bei Challenge " + (i + 1), 400);
            String tt = t.title() == null || t.title().isBlank() ? t.target() + "× " + LABELS.get(m) : t.title().trim();
            if (tt.length() > 80) throw new WebApplicationException("Challenge-Text: höchstens 80 Zeichen", 400);
            tasks.add(new Task("T" + (i + 1), tt, QuestCatalog.iconFor(m), m, t.target(), 0));
        }
        return new Event(id, title, subtitle, start, end, reward, in.rewardCoins(), tasks);
    }
}
