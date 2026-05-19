package boundary;

import boundary.dto.FriendRequestCreateDTO;
import boundary.dto.FriendRequestDTO;
import boundary.dto.FriendDTO;
import control.FriendRequestRepository;
import control.FriendshipRepository;
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

    @Inject
    FriendshipRepository friendshipRepository;

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

    @POST
    @Path("/requests/{id}/accept")
    public FriendRequestDTO accept(@PathParam("id") Long id) {
        FriendRequest updated = friendRequestRepository.updateStatus(id, FriendRequest.Status.ACCEPTED);
        if (updated == null) {
            throw new WebApplicationException("Request not found", 404);
        }

        // Persist the actual friendship relation.
        friendshipRepository.createIfMissing(updated.getFromPlayerId(), updated.getToPlayerId());

        return toDTO(updated);
    }

    @POST
    @Path("/requests/{id}/decline")
    public FriendRequestDTO decline(@PathParam("id") Long id) {
        FriendRequest updated = friendRequestRepository.updateStatus(id, FriendRequest.Status.DECLINED);
        if (updated == null) {
            throw new WebApplicationException("Request not found", 404);
        }
        return toDTO(updated);
    }

    @GET
    @Path("/list")
    public List<FriendDTO> listFriends(@QueryParam("playerId") String playerId) {
        if (playerId == null || playerId.isBlank()) {
            throw new WebApplicationException("playerId is required", 400);
        }
        return friendshipRepository.listFriendIds(playerId).stream().map(FriendDTO::new).toList();
    }

    @DELETE
    @Path("/remove")
    public void removeFriend(@QueryParam("playerId") String playerId,
                             @QueryParam("friendId") String friendId) {
        if (playerId == null || playerId.isBlank() || friendId == null || friendId.isBlank()) {
            throw new WebApplicationException("playerId and friendId are required", 400);
        }
        boolean removed = friendshipRepository.remove(playerId, friendId);
        if (!removed) {
            throw new WebApplicationException("Friendship not found", 404);
        }
    }

    @GET
    @Path("/requests/incoming/count")
    public long incomingCount(@QueryParam("playerId") String playerId) {
        if (playerId == null || playerId.isBlank()) {
            throw new WebApplicationException("playerId is required", 400);
        }
        return friendRequestRepository.findIncoming(playerId).size();
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
