package control;

import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Prod: legt die Stammdaten (Kategorien, Challenges, Ränge, Shop) aus {@code reference-data.sql} an,
 * aber nur, wenn noch keine Kategorien existieren. Die Datenbank wird in Prod nie gelöscht
 * ({@code schema-management.strategy=update}), deshalb darf das hier beliebig oft laufen.
 */
@ApplicationScoped
public class ReferenceDataSeeder {

    private static final Logger LOG = Logger.getLogger(ReferenceDataSeeder.class);
    static final String SCRIPT = "reference-data.sql";

    @Inject
    EntityManager em;

    @ConfigProperty(name = "challengr.seed-reference-data", defaultValue = "false")
    boolean enabled;

    void onStart(@Observes StartupEvent event) {
        if (enabled) seedIfEmpty();
    }

    /** @return Anzahl ausgeführter Statements (0 = Stammdaten waren schon da). */
    @Transactional
    public int seedIfEmpty() {
        long categories = ((Number) em.createNativeQuery("SELECT COUNT(*) FROM challenge_categories").getSingleResult()).longValue();
        if (categories > 0) {
            LOG.infof("Stammdaten vorhanden (%d Kategorien) – nichts zu tun", categories);
            return 0;
        }
        List<String> statements = statements(readScript());
        statements.forEach(sql -> em.createNativeQuery(sql).executeUpdate());
        LOG.infof("Stammdaten angelegt: %d Statements aus %s", statements.size(), SCRIPT);
        return statements.size();
    }

    private static String readScript() {
        try (InputStream in = ReferenceDataSeeder.class.getClassLoader().getResourceAsStream(SCRIPT)) {
            if (in == null) throw new IllegalStateException(SCRIPT + " fehlt");
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new IllegalStateException(SCRIPT + " nicht lesbar", e);
        }
    }

    /** Zerlegt das Skript in Statements: Kommentarzeilen weg, Ende = Zeile, die mit ';' endet. */
    static List<String> statements(String script) {
        List<String> result = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        for (String line : script.split("\n")) {
            String trimmed = line.trim();
            if (trimmed.isEmpty() || trimmed.startsWith("--")) continue;
            current.append(line).append('\n');
            if (trimmed.endsWith(";")) {
                String sql = current.toString().trim();
                result.add(sql.substring(0, sql.length() - 1));
                current.setLength(0);
            }
        }
        if (!current.toString().isBlank()) result.add(current.toString().trim());
        return result;
    }
}
