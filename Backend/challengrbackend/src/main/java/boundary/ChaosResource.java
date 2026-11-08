package boundary;

import control.ChaosService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

/** Chaos-Stunde für die App: läuft gerade eine? Dann Regel und Ende. Vorher wird nichts verraten. */
@Path("/api/chaos")
@Produces(MediaType.APPLICATION_JSON)
@Authenticated
public class ChaosResource {

    /** rule/title/description/endsAt sind null, wenn keine Chaos-Stunde läuft */
    public record Chaos(boolean active, String rule, String title, String description, String endsAt) {}

    @Inject
    ChaosService chaos;

    @GET
    public Chaos get() {
        return chaos.current()
                .map(w -> new Chaos(true, w.rule().name(), w.rule().title, w.rule().description, w.end().toString()))
                .orElse(new Chaos(false, null, null, null, null));
    }
}
