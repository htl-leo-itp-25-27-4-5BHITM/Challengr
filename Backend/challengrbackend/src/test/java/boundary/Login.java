package boundary;

import io.restassured.specification.RequestSpecification;

import static io.restassured.RestAssured.given;

/**
 * Login in Tests: im Test-Profil gilt der X-Player-Id-Header als Login (wie ein Keycloak-Token in Prod).
 */
public final class Login {

    private Login() {}

    public static RequestSpecification as(String playerId) {
        return given().header("X-Player-Id", playerId);
    }

    public static RequestSpecification admin() {
        return given().header("X-Player-Id", "test-admin").header("X-Player-Roles", "admin");
    }
}
