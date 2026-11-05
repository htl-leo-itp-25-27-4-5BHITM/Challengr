package control;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/** Auswahl der Check-in-Punkte aus OpenStreetMap (echte Overpass-Antwort aus Leonding/Linz). */
class LandmarkRulesTest {

    private List<LandmarkRules.Candidate> leonding() throws Exception {
        try (var in = getClass().getResourceAsStream("/overpass-leonding.json")) {
            return LandmarkRules.parse(new String(in.readAllBytes(), StandardCharsets.UTF_8));
        }
    }

    @Test
    void parseKeepsPublicPlacesAndDropsSombreOrPrivateOnes() throws Exception {
        var all = leonding();
        assertFalse(all.isEmpty());
        assertTrue(all.stream().anyMatch(c -> c.name().equals("Volksgarten") && c.category().equals("park")));
        assertTrue(all.stream().anyMatch(c -> c.category().equals("fountain")));
        assertTrue(all.stream().noneMatch(c -> c.name().toLowerCase().contains("gedenk")), "keine Gedenkstätten");
        assertTrue(all.stream().noneMatch(c -> c.name().contains("Kriegerdenkmal")));
        assertTrue(all.stream().noneMatch(c -> c.name().equals("Kinderbad Negrelliweg")), "access=children");
        assertTrue(all.stream().allMatch(c -> c.id().matches("osm-[nwr]-\\d+")));
    }

    @Test
    void selectionKeepsDistanceAndLimit() throws Exception {
        double[] school = {48.26832, 14.25138};
        var chosen = LandmarkRules.select(leonding(), List.of(school));
        assertTrue(chosen.size() <= LandmarkRules.MAX_PER_TILE);
        for (var a : chosen) {
            assertTrue(HotspotCatalog.distanceMeters(a.latitude(), a.longitude(), school[0], school[1]) >= LandmarkRules.MIN_SPACING_METERS);
            for (var b : chosen) {
                if (a != b) assertTrue(HotspotCatalog.distanceMeters(a.latitude(), a.longitude(), b.latitude(), b.longitude()) >= LandmarkRules.MIN_SPACING_METERS);
            }
        }
        // Museen/Sehenswürdigkeiten haben Vorrang vor Parks
        assertNotEquals("park", chosen.get(0).category());
    }

    @Test
    void tilesAndQuery() {
        String key = LandmarkRules.tileKey(48.26832, 14.25138);
        double[] b = LandmarkRules.tileBounds(key);
        assertTrue(b[0] <= 48.26832 && 48.26832 < b[2] && b[1] <= 14.25138 && 14.25138 < b[3]);
        var tiles = LandmarkRules.tilesAround(48.26832, 14.25138, 1500);
        assertTrue(tiles.contains(key));
        assertTrue(tiles.size() >= 1 && tiles.size() <= 9);
        String q = LandmarkRules.overpassQuery(key);
        assertTrue(q.contains("leisure") && q.contains("park") && q.contains("[\"name\"]"));
        assertFalse(q.contains("memorial"));
    }
}
