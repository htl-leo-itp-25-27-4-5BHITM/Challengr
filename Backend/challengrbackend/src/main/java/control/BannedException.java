package control;

import java.time.Instant;

/** Thrown when a player is currently banned and tries to use the API. */
public class BannedException extends RuntimeException {

    private final Instant banUntil;
    private final String banReason;

    public BannedException(Instant banUntil, String banReason) {
        super("Player is banned");
        this.banUntil = banUntil;
        this.banReason = banReason;
    }

    public Instant getBanUntil() {
        return banUntil;
    }

    public String getBanReason() {
        return banReason;
    }
}
