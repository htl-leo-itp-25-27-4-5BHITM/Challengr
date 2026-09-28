package boundary;

/** Eine Battle-Anfrage ist nicht erlaubt (Grund wird dem Spieler angezeigt). */
public class BattleRejectedException extends RuntimeException {
    public BattleRejectedException(String message) {
        super(message);
    }
}
