package control;

import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.*;

/** Aufbewahren und Dateinamen der Backups (ohne Datenbank). */
class BackupServiceTest {

    @Test
    void pruneKeepsTheNewestAndListsNewestFirst() throws Exception {
        Path dir = Files.createTempDirectory("backups");
        BackupService s = new BackupService();
        s.dir = dir.toString();
        for (int d = 1; d <= 20; d++) {
            Files.writeString(dir.resolve(String.format("challengr-2026-10-%02d-030000-auto.sql.gz", d)), "x");
        }
        Files.writeString(dir.resolve("challengr-2026-10-05-120000-manual.sql.gz"), "x");
        Files.writeString(dir.resolve("etwas-anderes.txt"), "x");
        s.prune();
        var list = s.list();
        assertEquals(BackupService.KEEP_AUTO + 1, list.size());
        assertEquals("challengr-2026-10-20-030000-auto.sql.gz", list.get(0).name());
        assertTrue(list.stream().anyMatch(b -> !b.automatic()));
        assertFalse(Files.exists(dir.resolve("challengr-2026-10-01-030000-auto.sql.gz")));
        assertTrue(Files.exists(dir.resolve("etwas-anderes.txt")), "fremde Dateien bleiben");
        assertTrue(s.file("challengr-2026-10-20-030000-auto.sql.gz").isPresent());
        assertTrue(s.file("../etwas-anderes.txt").isEmpty());
        assertTrue(s.file("etwas-anderes.txt").isEmpty());
    }
}
