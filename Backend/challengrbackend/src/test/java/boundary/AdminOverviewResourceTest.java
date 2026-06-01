package boundary;

import entity.Player;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import control.PlayerRepository;

import java.time.Instant;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@QuarkusTest
class AdminOverviewResourceTest {

    @Inject
    PlayerRepository playerRepository;

    @Test
    void overviewReturnsPlayersAndBansKpis() {
        // arrange
        playerRepository.createPlayer(new Player("Alice", 0, 0));
        playerRepository.createPlayer(new Player("Bob", 0, 0));

        var banned = new Player("Eve", 0, 0);
        banned.setBanUntil(Instant.now().plusSeconds(3600));
        banned.setBanReason("test");
        playerRepository.createPlayer(banned);

        // act + assert
        given()
                .when().get("/api/admin/overview")
                .then()
                .statusCode(200)
                .body("kpis", notNullValue())
                .body("kpis.size()", greaterThanOrEqualTo(2))
                .body("kpis.label", hasItems("Spieler (aktiv/gesamt)", "Aktive Bans"))
                .body("kpis.find { it.label == 'Aktive Bans' }.value", equalTo("1"));
    }
}
