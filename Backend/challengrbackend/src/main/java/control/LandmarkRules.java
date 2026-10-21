package control;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Welche OpenStreetMap-Orte Check-in-Punkte werden: nur öffentliche, belebte Orte (Parks, Museen, Brunnen,
 * Bibliotheken, Plätze …), keine Gedenkstätten, Friedhöfe oder privaten Orte. Reine Logik, ohne Netz – testbar.
 */
public final class LandmarkRules {

    /** Kachelgröße in Grad (≈ 2,2 × 2,2 km in Österreich) */
    public static final double TILE_LAT = 0.02, TILE_LON = 0.03;
    /** Höchstens so viele Punkte pro Kachel */
    public static final int MAX_PER_TILE = 12;
    /** Mindestabstand zwischen zwei Punkten (und zu festen Hotspots) */
    public static final double MIN_SPACING_METERS = 250;
    /** Check-in-Radius: Punkte (Brunnen, Denkmal) eng, Flächen (Park, Platz) großzügiger */
    public static final double RADIUS_POINT = 45, RADIUS_AREA = 80;

    /** Reihenfolge = Vorrang, wenn zwei Orte zu nah beieinander liegen. Schlüssel: "tag=wert" → Kategorie */
    static final Map<String, String> CATEGORIES = new java.util.LinkedHashMap<>();
    static {
        CATEGORIES.put("tourism=museum", "museum");
        CATEGORIES.put("tourism=attraction", "attraction");
        CATEGORIES.put("historic=castle", "castle");
        CATEGORIES.put("tourism=zoo", "zoo");
        CATEGORIES.put("tourism=theme_park", "attraction");
        CATEGORIES.put("historic=city_gate", "monument");
        CATEGORIES.put("historic=tower", "monument");
        CATEGORIES.put("historic=fort", "castle");
        CATEGORIES.put("historic=ruins", "castle");
        CATEGORIES.put("historic=monument", "monument");
        CATEGORIES.put("amenity=planetarium", "museum");
        CATEGORIES.put("tourism=gallery", "museum");
        CATEGORIES.put("amenity=theatre", "theatre");
        CATEGORIES.put("amenity=arts_centre", "theatre");
        CATEGORIES.put("tourism=viewpoint", "viewpoint");
        CATEGORIES.put("place=square", "square");
        CATEGORIES.put("amenity=townhall", "square");
        CATEGORIES.put("amenity=fountain", "fountain");
        CATEGORIES.put("amenity=library", "library");
        CATEGORIES.put("leisure=stadium", "stadium");
        CATEGORIES.put("leisure=park", "park");
    }

    /** Ernste Orte gehören nicht in ein Spiel (auch wenn sie als Denkmal/Sehenswürdigkeit eingetragen sind). */
    private static final Pattern SOMBRE = Pattern.compile(
            "gedenk|mahnmal|opfer|friedhof|grab|gruft|kz|konzentrationslager|holocaust|unfall|kriegerdenkmal|krieger|gefallen",
            Pattern.CASE_INSENSITIVE);

    public record Candidate(String id, String name, double latitude, double longitude, String category, double radiusMeters) {}

    private LandmarkRules() {}

    public static String tileKey(double latitude, double longitude) {
        return (long) Math.floor(latitude / TILE_LAT) + ":" + (long) Math.floor(longitude / TILE_LON);
    }

    /** Grenzen einer Kachel: [süd, west, nord, ost] */
    public static double[] tileBounds(String key) {
        String[] p = key.split(":");
        double s = Long.parseLong(p[0]) * TILE_LAT, w = Long.parseLong(p[1]) * TILE_LON;
        return new double[]{s, w, s + TILE_LAT, w + TILE_LON};
    }

    /** Alle Kacheln, die ein Kreis um die Position berührt. */
    public static List<String> tilesAround(double latitude, double longitude, double radiusMeters) {
        double dLat = radiusMeters / 111_320.0, dLon = radiusMeters / (111_320.0 * Math.cos(Math.toRadians(latitude)));
        List<String> keys = new ArrayList<>();
        for (long a = (long) Math.floor((latitude - dLat) / TILE_LAT); a <= (long) Math.floor((latitude + dLat) / TILE_LAT); a++)
            for (long b = (long) Math.floor((longitude - dLon) / TILE_LON); b <= (long) Math.floor((longitude + dLon) / TILE_LON); b++)
                keys.add(a + ":" + b);
        return keys;
    }

    /** Overpass-Abfrage für eine Kachel. */
    public static String overpassQuery(String tileKey) {
        double[] b = tileBounds(tileKey);
        String bbox = String.format(Locale.ROOT, "(%.5f,%.5f,%.5f,%.5f)", b[0], b[1], b[2], b[3]);
        StringBuilder q = new StringBuilder("[out:json][timeout:60];(");
        Map<String, List<String>> byKey = new java.util.LinkedHashMap<>();
        CATEGORIES.keySet().forEach(k -> byKey.computeIfAbsent(k.split("=")[0], x -> new ArrayList<>()).add(k.split("=")[1]));
        byKey.forEach((tag, values) -> q.append("nwr[\"").append(tag).append("\"~\"^(").append(String.join("|", values))
                .append(")$\"][\"name\"]").append(bbox).append(";"));
        return q.append(");out center tags 400;").toString();
    }

    /** Antwort von Overpass → Kandidaten (unpassende schon aussortiert). */
    public static List<Candidate> parse(String json) {
        List<Candidate> out = new ArrayList<>();
        try {
            for (JsonNode e : new ObjectMapper().readTree(json).path("elements")) {
                JsonNode tags = e.path("tags");
                String name = tags.path("name").asText("").trim();
                String category = categoryOf(tags);
                if (category == null || name.isEmpty() || name.length() > 100 || SOMBRE.matcher(name).find()) continue;
                String access = tags.path("access").asText("");
                if (access.equals("private") || access.equals("no") || access.equals("customers") || access.equals("children")) continue;
                if (tags.has("memorial")) continue;  // als Denkmal getaggte Gedenkstätten
                JsonNode pos = e.has("center") ? e.path("center") : e;
                if (!pos.has("lat") || !pos.has("lon")) continue;
                String type = e.path("type").asText("n").substring(0, 1);
                boolean area = !type.equals("n") || category.equals("park") || category.equals("square");
                out.add(new Candidate("osm-" + type + "-" + e.path("id").asLong(), name,
                        pos.path("lat").asDouble(), pos.path("lon").asDouble(), category, area ? RADIUS_AREA : RADIUS_POINT));
            }
        } catch (Exception ex) {
            throw new IllegalArgumentException("Overpass-Antwort nicht lesbar", ex);
        }
        return out;
    }

    private static String categoryOf(JsonNode tags) {
        for (var entry : CATEGORIES.entrySet()) {
            String[] kv = entry.getKey().split("=");
            if (kv[1].equals(tags.path(kv[0]).asText(null))) return entry.getValue();
        }
        return null;
    }

    private static int priority(Candidate c) {
        int i = 0;
        for (var entry : CATEGORIES.entrySet()) {
            if (entry.getValue().equals(c.category())) return i;
            i++;
        }
        return i;
    }

    /** Auswahl: wichtige Orte zuerst, mit Mindestabstand zueinander und zu den festen Hotspots, höchstens MAX_PER_TILE. */
    public static List<Candidate> select(List<Candidate> candidates, List<double[]> blocked) {
        List<Candidate> sorted = new ArrayList<>(candidates);
        sorted.sort(java.util.Comparator.comparingInt(LandmarkRules::priority).thenComparing(Candidate::id));
        List<Candidate> chosen = new ArrayList<>();
        for (Candidate c : sorted) {
            if (chosen.size() >= MAX_PER_TILE) break;
            boolean tooClose = chosen.stream().anyMatch(o -> HotspotCatalog.distanceMeters(c.latitude(), c.longitude(), o.latitude(), o.longitude()) < MIN_SPACING_METERS)
                    || blocked.stream().anyMatch(p -> HotspotCatalog.distanceMeters(c.latitude(), c.longitude(), p[0], p[1]) < MIN_SPACING_METERS);
            if (!tooClose) chosen.add(c);
        }
        return chosen;
    }
}
