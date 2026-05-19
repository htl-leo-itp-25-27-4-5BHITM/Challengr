package boundary.dto;

import com.fasterxml.jackson.annotation.JsonAlias;

public class KeycloakRegistrationDTO {

    @JsonAlias({"keycloakId", "id", "sub"})
    private String keycloakId;

    @JsonAlias({"username", "preferred_username", "name"})
    private String username;

    @JsonAlias({"email"})
    private String email;

    public String getKeycloakId() {
        return keycloakId;
    }

    public void setKeycloakId(String keycloakId) {
        this.keycloakId = keycloakId;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }
}
