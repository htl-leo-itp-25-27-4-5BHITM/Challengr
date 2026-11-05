package boundary;

import control.QuestService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import security.CurrentPlayer;

/** Tagesaufgaben und Events des eingeloggten Spielers. */
@Path("/api/quests")
@Produces(MediaType.APPLICATION_JSON)
@Authenticated
public class QuestResource {

    @Inject
    QuestService quests;

    @Inject
    CurrentPlayer me;

    @Inject
    control.BanEnforcementService banEnforcement;

    @GET
    public QuestService.Board board() {
        return quests.board(me.id());
    }

    @POST
    @Path("/daily/{taskId}/claim")
    public QuestService.Board claimDaily(@PathParam("taskId") String taskId) {
        banEnforcement.assertNotBanned(me.id());
        return quests.claimDaily(me.id(), taskId);
    }

    @POST
    @Path("/events/{eventId}/claim")
    public QuestService.Board claimEvent(@PathParam("eventId") String eventId) {
        banEnforcement.assertNotBanned(me.id());
        return quests.claimEvent(me.id(), eventId);
    }
}
