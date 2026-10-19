package control;

import com.fasterxml.jackson.databind.JsonNode;
import entity.FeedbackStatus;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * TestFlight-Feedback (Screenshots mit Text und Absturzberichte) aus App Store Connect,
 * ergänzt um unseren "Erledigt"-Haken. Apple-Antworten werden eine Minute zwischengespeichert.
 */
@ApplicationScoped
public class TestFlightFeedbackService {

    public record Item(String id, String kind, String createdAt, String comment, String tester, String testerEmail,
                       String device, String osVersion, String appVersion, List<String> screenshots,
                       boolean done, String doneAt, String doneBy) {}

    public record Feed(boolean configured, List<Item> items, String error) {}

    private static final Duration CACHE = Duration.ofMinutes(1);
    private static final int MAX_PAGES = 5;

    @Inject
    AppStoreConnectClient asc;

    @Inject
    EntityManager em;

    private List<Item> cachedItems;
    private Instant cachedAt = Instant.EPOCH;

    public boolean isConfigured() {
        return asc.isConfigured();
    }

    /** @param refresh Apple neu fragen statt der Kopie der letzten Minute */
    public Feed feed(boolean refresh) {
        if (!asc.isConfigured()) return new Feed(false, List.of(), null);
        try {
            List<Item> fromApple = fromApple(refresh);
            Map<String, FeedbackStatus> status = statusById();
            List<Item> items = fromApple.stream().map(i -> withStatus(i, status.get(i.id()))).toList();
            return new Feed(true, items, null);
        } catch (AppStoreConnectClient.AscException e) {
            return new Feed(true, List.of(), explain(e));
        }
    }

    @Transactional
    public void setDone(String feedbackId, boolean done, String by) {
        FeedbackStatus s = em.find(FeedbackStatus.class, feedbackId);
        if (s == null) {
            s = new FeedbackStatus(feedbackId);
            em.persist(s);
        }
        s.mark(done, by);
    }

    /** Absturzbericht als Text (bei Apple nachgeladen, weil er groß sein kann). */
    public String crashLog(String feedbackId) {
        JsonNode log = asc.get("/v1/betaFeedbackCrashSubmissions/" + feedbackId + "/crashLog");
        return log.path("data").path("attributes").path("logText").asText("");
    }

    private synchronized List<Item> fromApple(boolean refresh) {
        if (!refresh && cachedItems != null && Instant.now().isBefore(cachedAt.plus(CACHE))) return cachedItems;
        String app = asc.appId();
        List<Item> items = new ArrayList<>();
        items.addAll(load("/v1/apps/" + app + "/betaFeedbackScreenshotSubmissions", "SCREENSHOT"));
        items.addAll(load("/v1/apps/" + app + "/betaFeedbackCrashSubmissions", "CRASH"));
        items.sort(Comparator.comparing(Item::createdAt, Comparator.nullsLast(Comparator.reverseOrder())));
        cachedItems = items;
        cachedAt = Instant.now();
        return items;
    }

    /** Alle Seiten einer Liste; Tester und Build über "include", falls Apple das für die Liste anbietet. */
    private List<Item> load(String path, String kind) {
        JsonNode page;
        try {
            page = asc.get(path + "?include=build,tester&limit=200");
        } catch (AppStoreConnectClient.AscException e) {
            if (e.status != 400) throw e;
            page = asc.get(path + "?limit=200");   // ohne Zusatzinfos
        }
        List<Item> items = new ArrayList<>();
        for (int n = 0; n < MAX_PAGES && page != null; n++) {
            Map<String, JsonNode> included = new HashMap<>();
            page.path("included").forEach(i -> included.put(i.path("type").asText() + ":" + i.path("id").asText(), i));
            for (JsonNode d : page.path("data")) items.add(toItem(d, kind, included));
            String next = page.path("links").path("next").asText(null);
            page = next == null || next.isBlank() ? null : asc.get(next);
        }
        return items;
    }

    static Item toItem(JsonNode d, String kind, Map<String, JsonNode> included) {
        JsonNode a = d.path("attributes");
        JsonNode tester = included.get("betaTesters:" + d.path("relationships").path("tester").path("data").path("id").asText());
        JsonNode build = included.get("builds:" + d.path("relationships").path("build").path("data").path("id").asText());
        String testerName = tester == null ? null
                : (tester.path("attributes").path("firstName").asText("") + " " + tester.path("attributes").path("lastName").asText("")).trim();
        List<String> shots = new ArrayList<>();
        a.path("screenshots").forEach(s -> { if (s.hasNonNull("url")) shots.add(s.path("url").asText()); });
        return new Item(
                d.path("id").asText(),
                kind,
                text(a, "createdDate"),
                text(a, "comment"),
                testerName == null || testerName.isBlank() ? null : testerName,
                text(a, "email"),
                text(a, "deviceModel"),
                text(a, "osVersion"),
                build == null ? null : text(build.path("attributes"), "version"),
                shots, false, null, null);
    }

    private static String text(JsonNode node, String field) {
        JsonNode v = node.path(field);
        return v.isMissingNode() || v.isNull() || v.asText().isBlank() ? null : v.asText();
    }

    private Map<String, FeedbackStatus> statusById() {
        return em.createQuery("SELECT s FROM FeedbackStatus s", FeedbackStatus.class).getResultList().stream()
                .collect(Collectors.toMap(FeedbackStatus::getFeedbackId, Function.identity()));
    }

    private static Item withStatus(Item i, FeedbackStatus s) {
        if (s == null) return i;
        return new Item(i.id(), i.kind(), i.createdAt(), i.comment(), i.tester(), i.testerEmail(), i.device(),
                i.osVersion(), i.appVersion(), i.screenshots(), s.isDone(),
                s.getDoneAt() == null ? null : s.getDoneAt().toString(), s.getDoneBy());
    }

    static String explain(AppStoreConnectClient.AscException e) {
        return switch (e.status) {
            case 401 -> "Apple lehnt den API-Schlüssel ab – Issuer-ID, Key-ID und .p8-Datei prüfen.";
            case 403 -> "Dem API-Schlüssel fehlen Rechte – in App Store Connect mindestens die Rolle \"Developer\" geben.";
            case 404 -> "Bei Apple nicht gefunden: " + e.getMessage();
            default -> "App Store Connect: " + e.getMessage();
        };
    }
}
