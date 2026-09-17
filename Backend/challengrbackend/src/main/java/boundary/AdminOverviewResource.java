package boundary;

import control.AdminOverviewService;
import jakarta.annotation.security.PermitAll;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

@Path("/api/admin/overview")
@Produces(MediaType.APPLICATION_JSON)
@PermitAll // TODO: restrict to admin role once dashboard uses Bearer tokens
public class AdminOverviewResource {

    private static final DateTimeFormatter AT_FORMAT =
            DateTimeFormatter.ofPattern("dd.MM.yyyy, HH:mm").withZone(ZoneId.systemDefault());

    @Inject
    AdminOverviewService service;

    public record Kpi(String label, String value, String tone, String icon) {}
    public record SetupWarning(String title, String detail, String tone) {}
    public record AuditEvent(String type, String detail, String at) {}

    public record OverviewResponse(List<Kpi> kpis, List<SetupWarning> setupWarnings, List<AuditEvent> auditEvents) {}

    @GET
    public OverviewResponse get() {
        var o = service.getOverview();

        List<Kpi> kpis = new ArrayList<>();
        kpis.add(new Kpi(
                "Spieler (aktiv/gesamt)",
                o.players().active() + " / " + o.players().total(),
                "primary",
                "👥"
        ));
        kpis.add(new Kpi(
                "Aktive Bans",
                String.valueOf(o.activeBans()),
                o.activeBans() > 0 ? "danger" : "info",
                "⛔"
        ));
        kpis.add(new Kpi(
                "Battles (heute / gesamt)",
                o.battlesToday() + " / " + o.totalBattles(),
                "info",
                "⚔️"
        ));
        kpis.add(new Kpi(
                "Challenges im Katalog",
                String.valueOf(o.totalChallenges()),
                "primary",
                "🏆"
        ));
        kpis.add(new Kpi(
                "Shop-Käufe gesamt",
                String.valueOf(o.totalShopPurchases()),
                "info",
                "🛍️"
        ));
        kpis.add(new Kpi(
                "Beliebteste Kategorie",
                o.mostPlayedCategory() != null ? o.mostPlayedCategory() : "–",
                "primary",
                "🔥"
        ));
        kpis.add(new Kpi(
                "Top Spieler",
                o.topPlayer() != null ? o.topPlayer().name() + " (" + o.topPlayer().points() + " P.)" : "–",
                "warning",
                "👑"
        ));

        List<SetupWarning> setupWarnings = new ArrayList<>();
        setupWarnings.add(new SetupWarning("Backend & Datenbank", "Antwortet normal", "ok"));
        if (o.activeBans() > 0) {
            setupWarnings.add(new SetupWarning(
                    "Aktive Bans",
                    o.activeBans() + " Spieler sind aktuell gesperrt",
                    "warn"
            ));
        }

        List<AuditEvent> auditEvents = service.getRecentActivity(8).stream()
                .map(a -> new AuditEvent(a.type(), a.detail(), AT_FORMAT.format(a.at())))
                .toList();

        return new OverviewResponse(kpis, setupWarnings, auditEvents);
    }
}
