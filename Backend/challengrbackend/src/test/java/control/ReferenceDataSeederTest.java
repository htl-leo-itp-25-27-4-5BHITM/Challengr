package control;

import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/** A1: Stammdaten werden nur angelegt, wenn sie fehlen – nie doppelt, nie gelöscht. */
@QuarkusTest
class ReferenceDataSeederTest {

    @Inject
    ReferenceDataSeeder seeder;

    @Inject
    EntityManager em;

    @Test
    void doesNothingWhenReferenceDataExists() {
        long before = count("challenges");
        assertEquals(0, seeder.seedIfEmpty());
        assertEquals(before, count("challenges"), "keine doppelten Challenges");
    }

    @Test
    void splitsTheScriptIntoStatements() {
        List<String> statements = ReferenceDataSeeder.statements("""
                -- Kommentar
                INSERT INTO rank (name) VALUES
                    ('A'),
                    ('B');

                INSERT INTO rank (name) VALUES ('C');
                """);
        assertEquals(2, statements.size());
        assertTrue(statements.get(0).startsWith("INSERT INTO rank"));
        assertFalse(statements.get(0).endsWith(";"));
    }

    @Test
    void referenceScriptHasNoPlayers() {
        String script = new String(assertDoesNotThrow(() ->
                getClass().getClassLoader().getResourceAsStream(ReferenceDataSeeder.SCRIPT).readAllBytes()));
        assertFalse(script.toLowerCase().contains("insert into player"), "Demo-Spieler gehören nicht in die Prod-Stammdaten");
        assertTrue(ReferenceDataSeeder.statements(script).size() >= 6);
    }

    private long count(String table) {
        return QuarkusTransaction.requiringNew().call(() ->
                ((Number) em.createNativeQuery("SELECT COUNT(*) FROM " + table).getSingleResult()).longValue());
    }
}
