package boundary;

import control.AdminOverviewService;
import jakarta.annotation.security.PermitAll;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

@Path("/api/admin/overview")
@Produces(MediaType.APPLICATION_JSON)
@PermitAll // TODO: restrict to admin role once dashboard uses Bearer tokens
public class AdminOverviewResource {

    @Inject
    AdminOverviewService service;

    public record Kpi(String label, String value, String tone, String icon) {}
    public record SetupWarning(String title, String detail, String tone) {}
    public record AuditEvent(String type, String detail, String at) {}

    public record OverviewResponse(List<Kpi> kpis, List<SetupWarning> setupWarnings, List<AuditEvent> auditEvents) {}

    @GET
    public OverviewResponse get() {
        var o = service.getOverview();

        // KPIs requested by you:
        // - Spieler (aktiv/gesamt)
        // - Bans
        var kpis = List.of(
                new Kpi(
                        "Spieler (aktiv/gesamt)",
                        o.players().active() + " / " + o.players().total(),
                        "primary",
                        "👥"
                ),
                new Kpi(
                        "Aktive Bans",
                        String.valueOf(o.activeBans()),
                        o.activeBans() > 0 ? "danger" : "info",
                        "⛔"
                )
        );

        // Minimal warnings/audit for now (can be extended later).
        var setupWarnings = List.of(
                new SetupWarning("Backend", "Admin overview endpoint online", "ok")
        );

        var audit = List.of(
                new AuditEvent("INFO", "Overview loaded", "now")
        );

        return new OverviewResponse(kpis, setupWarnings, audit);
    }
}
