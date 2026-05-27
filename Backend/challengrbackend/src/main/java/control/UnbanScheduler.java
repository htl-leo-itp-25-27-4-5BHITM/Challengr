package control;

import io.quarkus.logging.Log;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class UnbanScheduler {

    @Inject
    BanService banService;

    // Every 1 minute; cheap query + only touches expired bans
    @Scheduled(every = "60s")
    void unbanExpired() {
        int count = banService.unbanExpired();
        if (count > 0) {
            Log.infof("Unbanned %d expired players", count);
        }
    }
}
