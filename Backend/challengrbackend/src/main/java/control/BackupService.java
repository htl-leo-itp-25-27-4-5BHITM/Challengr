package control;

import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.nio.file.*;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.ReentrantLock;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import java.util.zip.GZIPOutputStream;

/**
 * Datenbank-Sicherungen mit pg_dump (im Server-Image installiert) als .sql.gz auf einem eigenen Volume.
 * Jede Nacht um 3 Uhr automatisch (14 aufbewahrt), zusätzlich auf Knopfdruck im Dashboard (20 aufbewahrt).
 * Zurückspielen bewusst NICHT übers Dashboard – nur per Hand (docs/PROJEKT_STAND.md).
 */
@ApplicationScoped
public class BackupService {

    private static final Logger LOG = Logger.getLogger(BackupService.class);
    static final ZoneId ZONE = ActivityTracker.ZONE;
    static final DateTimeFormatter STAMP = DateTimeFormatter.ofPattern("yyyy-MM-dd-HHmmss");
    /** challengr-2026-10-21-030000-auto.sql.gz */
    static final Pattern NAME = Pattern.compile("challengr-\\d{4}-\\d{2}-\\d{2}-\\d{6}-(auto|manual)\\.sql\\.gz");
    static final int KEEP_AUTO = 14, KEEP_MANUAL = 20;

    public record BackupFile(String name, long sizeBytes, String createdAt, boolean automatic) {}

    @ConfigProperty(name = "challengr.backup.dir", defaultValue = "/backups")
    String dir;

    @ConfigProperty(name = "challengr.backup.pg-dump", defaultValue = "pg_dump")
    String pgDump;

    @ConfigProperty(name = "quarkus.datasource.jdbc.url")
    String jdbcUrl;

    @ConfigProperty(name = "quarkus.datasource.username")
    String dbUser;

    @ConfigProperty(name = "quarkus.datasource.password")
    String dbPassword;

    private final ReentrantLock running = new ReentrantLock();
    private volatile Instant lastSuccess;
    private volatile String lastError;

    public Instant lastSuccess() { return lastSuccess; }
    public String lastError() { return lastError; }

    /** Läuft pg_dump hier überhaupt? (Tests/Entwicklung: meist nicht) */
    public boolean available() {
        if (!jdbcUrl.startsWith("jdbc:postgresql:")) return false;
        try {
            Process p = new ProcessBuilder(pgDump, "--version").redirectErrorStream(true).start();
            return p.waitFor(10, TimeUnit.SECONDS) && p.exitValue() == 0;
        } catch (Exception e) {
            return false;
        }
    }

    @Scheduled(cron = "0 0 3 * * ?", timeZone = "Europe/Vienna", identity = "nightly-backup")
    void nightly() {
        try {
            create(true);
        } catch (Exception e) {
            LOG.errorf("Nächtliches Backup fehlgeschlagen: %s", e.getMessage());
        }
    }

    /** Neues Backup anlegen. Läuft schon eins, wird abgelehnt. */
    public BackupFile create(boolean automatic) throws IOException {
        if (!running.tryLock()) throw new IllegalStateException("Es läuft schon ein Backup");
        try {
            if (!jdbcUrl.startsWith("jdbc:postgresql:")) throw new IllegalStateException("Backups gibt es nur mit PostgreSQL");
            Path folder = Files.createDirectories(Path.of(dir));
            String name = "challengr-" + LocalDateTime.now(ZONE).format(STAMP) + (automatic ? "-auto" : "-manual") + ".sql.gz";
            Path target = folder.resolve(name), tmp = folder.resolve(name + ".part");
            URI db = URI.create(jdbcUrl.substring("jdbc:".length()));
            ProcessBuilder pb = new ProcessBuilder(pgDump, "--no-owner", "--no-privileges",
                    "-h", db.getHost(), "-p", String.valueOf(db.getPort() > 0 ? db.getPort() : 5432),
                    "-U", dbUser, "-d", db.getPath().replaceFirst("^/", ""));
            pb.environment().put("PGPASSWORD", dbPassword);   // nie in der Befehlszeile (wäre in ps sichtbar)
            pb.redirectError(ProcessBuilder.Redirect.DISCARD);
            Process p = pb.start();
            try (InputStream in = p.getInputStream(); OutputStream out = new GZIPOutputStream(Files.newOutputStream(tmp))) {
                in.transferTo(out);
            }
            if (!p.waitFor(5, TimeUnit.MINUTES) || p.exitValue() != 0 || Files.size(tmp) < 200) {
                p.destroyForcibly();
                Files.deleteIfExists(tmp);
                throw new IOException("pg_dump fehlgeschlagen (Exit " + (p.isAlive() ? "Timeout" : p.exitValue()) + ")");
            }
            Files.move(tmp, target, StandardCopyOption.ATOMIC_MOVE);
            lastSuccess = Instant.now();
            lastError = null;
            prune();
            LOG.infof("Backup erstellt: %s (%d KB)", name, Files.size(target) / 1024);
            return describe(target);
        } catch (IOException | RuntimeException e) {
            lastError = e.getMessage();
            throw e;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("Backup abgebrochen", e);
        } finally {
            running.unlock();
        }
    }

    public List<BackupFile> list() throws IOException {
        Path folder = Path.of(dir);
        if (!Files.isDirectory(folder)) return List.of();
        try (Stream<Path> files = Files.list(folder)) {
            return files.filter(f -> NAME.matcher(f.getFileName().toString()).matches())
                    .sorted(Comparator.comparing((Path f) -> f.getFileName().toString().substring(10, 27)).reversed())
                    .map(this::describe).toList();
        }
    }

    /** Datei zum Herunterladen – nur echte Backup-Namen, kein Weg aus dem Ordner heraus. */
    public Optional<Path> file(String name) {
        if (name == null || !NAME.matcher(name).matches()) return Optional.empty();
        Path f = Path.of(dir).resolve(name).normalize();
        return f.startsWith(Path.of(dir).normalize()) && Files.isRegularFile(f) ? Optional.of(f) : Optional.empty();
    }

    /** Älteste löschen, damit das Volume nicht vollläuft. */
    void prune() throws IOException {
        List<BackupFile> all = list();
        prune(all.stream().filter(BackupFile::automatic).toList(), KEEP_AUTO);
        prune(all.stream().filter(b -> !b.automatic()).toList(), KEEP_MANUAL);
    }

    private void prune(List<BackupFile> newestFirst, int keep) throws IOException {
        for (int i = keep; i < newestFirst.size(); i++) Files.deleteIfExists(Path.of(dir).resolve(newestFirst.get(i).name()));
    }

    private BackupFile describe(Path f) {
        try {
            String n = f.getFileName().toString();
            return new BackupFile(n, Files.size(f), Files.getLastModifiedTime(f).toInstant().toString(), n.endsWith("-auto.sql.gz"));
        } catch (IOException e) {
            throw new IllegalStateException(e);
        }
    }
}
