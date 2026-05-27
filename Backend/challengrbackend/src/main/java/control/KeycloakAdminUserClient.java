package control;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.core.MediaType;

import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

@Path("/admin/realms/{realm}/users")
@RegisterRestClient(configKey = "keycloak-admin")
public interface KeycloakAdminUserClient {

    @JsonIgnoreProperties(ignoreUnknown = true)
    record UserRepresentation(
            String id,
            String username,
            Boolean enabled,
            @JsonProperty("emailVerified") Boolean emailVerified
    ) {
    }

    @GET
    @Path("/{userId}")
    @Produces(MediaType.APPLICATION_JSON)
    UserRepresentation getUser(
            @HeaderParam("Authorization") String authorization,
            @PathParam("realm") String realm,
            @PathParam("userId") String userId
    );

    @PUT
    @Path("/{userId}")
    @Consumes(MediaType.APPLICATION_JSON)
    void updateUser(
            @HeaderParam("Authorization") String authorization,
            @PathParam("realm") String realm,
            @PathParam("userId") String userId,
            UserRepresentation body
    );
}
