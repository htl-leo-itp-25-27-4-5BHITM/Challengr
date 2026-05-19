package boundary;

import boundary.dto.FriendRequestCreateDTO;
import boundary.dto.FriendRequestDTO;
import control.FriendRequestRepository;
import entity.FriendRequest;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

@Path("/api/friends")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class FriendRequestResource {

    @Inject
    FriendRequestRepository friendRequestRepository;

    @POST
    @Path("/requests")
    public FriendRequestDTO createRequest(FriendRequestCreateDTO dto) {
        if (dto == null) {
            throw new WebApplicationException("Missing body", 400);
        }
        FriendRequest request = friendRequestRepository.create(dto.fromPlayerId(), dto.toPlayerId());
        return toDTO(request);
    }

    @GET
    @Path("/requests/outgoing")
    public List<FriendRequestDTO> outgoing(@QueryParam("playerId") String playerId) {
        if (playerId == null || playerId.isBlank()) {
            throw new WebApplicationException("playerId is required", 400);
        }
        return friendRequestRepository.findOutgoing(playerId).stream().map(this::toDTO).toList();
    }

    @GET
    @Path("/requests/incoming")
    public List<FriendRequestDTO> incoming(@QueryParam("playerId") String playerId) {
        if (playerId == null || playerId.isBlank()) {
            throw new WebApplicationException("playerId is required", 400);
        }
        return friendRequestRepository.findIncoming(playerId).stream().map(this::toDTO).toList();
    }

    private FriendRequestDTO toDTO(FriendRequest r) {
        return new FriendRequestDTO(
                r.getId(),
                r.getFromPlayerId(),
                r.getToPlayerId(),
                r.getStatus(),
                r.getCreatedAt()
        );
    }
}
