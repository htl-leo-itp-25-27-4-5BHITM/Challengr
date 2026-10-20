package control;

import com.fasterxml.jackson.databind.JsonNode;
import entity.FeedbackStatus;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
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

    private static final DateTimeFormatter DATE =
            DateTimeFormatter.ofPattern("dd.MM.yyyy, HH:mm").withZone(ZoneId.of("Europe/Vienna"));
    private final HttpClient images = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10)).followRedirects(HttpClient.Redirect.NORMAL).build();

    /**
     * ZIP zum Aufheben: feedback.md + bilder/ (Screenshots fest eingepackt – Apples Bild-Links laufen ab)
     * + abstuerze/ (vollständige Absturzberichte).
     * @param filter "open", "done" oder "all"
     */
    public byte[] exportZip(String filter) {
        Feed feed = feed(false);
        List<Item> items = feed.items().stream()
                .filter(i -> "all".equals(filter) || ("done".equals(filter) == i.done()))
                .toList();
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ZipOutputStream zip = new ZipOutputStream(bytes, StandardCharsets.UTF_8)) {
            StringBuilder md = new StringBuilder();
            md.append("# Challengr – TestFlight-Feedback\n\n")
              .append("Exportiert am ").append(DATE.format(Instant.now())).append(" · ")
              .append(items.size()).append(" Einträge (")
              .append(switch (filter) { case "done" -> "erledigt"; case "all" -> "alle"; default -> "offen"; })
              .append(")\n");
            if (feed.error() != null) md.append("\n> ⚠️ ").append(feed.error()).append("\n");
            for (Item i : items) {
                md.append("\n---\n\n## ").append("CRASH".equals(i.kind()) ? "Absturz" : "Feedback")
                  .append(" – ").append(i.createdAt() == null ? "?" : DATE.format(Instant.parse(i.createdAt()))).append("\n\n");
                md.append("- **Status:** ").append(i.done() ? "erledigt" + (i.doneBy() == null ? "" : " (" + i.doneBy() + ")") : "offen").append("\n");
                if (i.tester() != null || i.testerEmail() != null)
                    md.append("- **Tester:** ").append(i.tester() != null ? i.tester() : i.testerEmail()).append("\n");
                if (i.device() != null)
                    md.append("- **Gerät:** ").append(i.device()).append(i.osVersion() == null ? "" : " · iOS " + i.osVersion()).append("\n");
                if (i.appVersion() != null) md.append("- **Build:** ").append(i.appVersion()).append("\n");
                md.append("- **ID:** `").append(i.id()).append("`\n\n");
                md.append(i.comment() == null ? "_(kein Text)_" : "> " + i.comment().replace("\n", "\n> ")).append("\n");
                int n = 1;
                for (String url : i.screenshots()) {
                    String name = "bilder/" + i.id() + "-" + n++ + ".png";
                    byte[] img = download(url);
                    if (img == null) {
                        md.append("\n_(Screenshot ").append(n - 1).append(" konnte nicht geladen werden)_\n");
                        continue;
                    }
                    zip.putNextEntry(new ZipEntry(name));
                    zip.write(img);
                    zip.closeEntry();
                    md.append("\n![Screenshot](").append(name).append(")\n");
                }
                if ("CRASH".equals(i.kind())) {
                    try {
                        String log = crashLog(i.id());
                        String name = "abstuerze/" + i.id() + ".txt";
                        zip.putNextEntry(new ZipEntry(name));
                        zip.write(log.getBytes(StandardCharsets.UTF_8));
                        zip.closeEntry();
                        md.append("\nAbsturzbericht: [").append(name).append("](").append(name).append(")\n");
                    } catch (AppStoreConnectClient.AscException e) {
                        md.append("\n_(Absturzbericht nicht verfügbar)_\n");
                    }
                }
            }
            zip.putNextEntry(new ZipEntry("feedback.md"));
            zip.write(md.toString().getBytes(StandardCharsets.UTF_8));
            zip.closeEntry();
        } catch (IOException e) {
            throw new IllegalStateException("Export fehlgeschlagen", e);
        }
        return bytes.toByteArray();
    }

    /** Screenshot laden – nur https (die Links kommen aus Apples Antwort). null, wenn es nicht klappt. */
    protected byte[] download(String url) {
        if (url == null || !url.startsWith("https://")) return null;
        try {
            HttpResponse<byte[]> r = images.send(HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofSeconds(20)).GET().build(),
                    HttpResponse.BodyHandlers.ofByteArray());
            return r.statusCode() == 200 ? r.body() : null;
        } catch (IOException e) {
            return null;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return null;
        }
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
