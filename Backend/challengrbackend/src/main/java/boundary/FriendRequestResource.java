package boundary;

import boundary.dto.FriendRequestCreateDTO;
import boundary.dto.FriendRequestDTO;
import boundary.dto.FriendDTO;
import boundary.dto.FriendGiftCreateDTO;
import boundary.dto.FriendGiftDTO;
import control.FriendRequestRepository;
import control.FriendGiftRepository;
import control.FriendshipRepository;
import control.BanEnforcementService;
import entity.FriendRequest;
import entity.FriendGift;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.HttpHeaders;
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

    @Inject
    FriendGiftRepository friendGiftRepository;

    @Inject
    BanEnforcementService banEnforcement;

    @Inject
    HttpHeaders headers;

    private void enforceNotBanned() {
        banEnforcement.assertNotBanned(headers.getHeaderString(BanEnforcementService.PLAYER_ID_HEADER));
    }

    @POST
    @Path("/requests")
    public FriendRequestDTO createRequest(FriendRequestCreateDTO dto) {
        enforceNotBanned();
        if (dto == null) {
            throw new WebApplicationException("Missing body", 400);
        }
        FriendRequest request = friendRequestRepository.create(dto.fromPlayerId(), dto.toPlayerId());
        GameSocket.emitFriendRequestCreated(request.getId(), request.getFromPlayerId(), request.getToPlayerId());
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
        enforceNotBanned();
        FriendRequest updated = friendRequestRepository.updateStatus(id, FriendRequest.Status.ACCEPTED);
        if (updated == null) {
            throw new WebApplicationException("Request not found", 404);
        }

        // Persist the actual friendship relation.
        friendshipRepository.createIfMissing(updated.getFromPlayerId(), updated.getToPlayerId());

        GameSocket.emitFriendRequestUpdated(updated.getId(), updated.getFromPlayerId(), updated.getToPlayerId(), updated.getStatus().name());

        return toDTO(updated);
    }

    @POST
    @Path("/requests/{id}/decline")
    public FriendRequestDTO decline(@PathParam("id") Long id) {
        enforceNotBanned();
        FriendRequest updated = friendRequestRepository.updateStatus(id, FriendRequest.Status.DECLINED);
        if (updated == null) {
            throw new WebApplicationException("Request not found", 404);
        }
        GameSocket.emitFriendRequestUpdated(updated.getId(), updated.getFromPlayerId(), updated.getToPlayerId(), updated.getStatus().name());
        return toDTO(updated);
    }

    @GET
    @Path("/list")
    public List<FriendDTO> listFriends(@QueryParam("playerId") String playerId) {
        enforceNotBanned();
        if (playerId == null || playerId.isBlank()) {
            throw new WebApplicationException("playerId is required", 400);
        }
        return friendshipRepository.listFriendIds(playerId).stream().map(FriendDTO::new).toList();
    }

    @POST
    @Path("/gifts")
    public FriendGiftDTO createGift(FriendGiftCreateDTO dto) {
        enforceNotBanned();
        if (dto == null) {
            throw new WebApplicationException("Missing body", 400);
        }
        if (!friendshipRepository.areFriends(dto.fromPlayerId(), dto.toPlayerId())) {
            throw new WebApplicationException("Gift can only be sent to friends", 400);
        }
        FriendGift gift = friendGiftRepository.create(dto.fromPlayerId(), dto.toPlayerId());
        return toDTO(gift);
    }

    @GET
    @Path("/gifts/incoming")
    public List<FriendGiftDTO> incomingGifts(@QueryParam("playerId") String playerId) {
        enforceNotBanned();
        if (playerId == null || playerId.isBlank()) {
            throw new WebApplicationException("playerId is required", 400);
        }
        return friendGiftRepository.findIncomingPending(playerId).stream().map(this::toDTO).toList();
    }

    @POST
    @Path("/gifts/{id}/claim")
    public FriendGiftDTO claimGift(@PathParam("id") Long id, @QueryParam("playerId") String playerId) {
        enforceNotBanned();
        if (playerId == null || playerId.isBlank()) {
            throw new WebApplicationException("playerId is required", 400);
        }
        try {
            FriendGift updated = friendGiftRepository.claim(id, playerId);
            if (updated == null) {
                throw new WebApplicationException("Gift not found", 404);
            }
            return toDTO(updated);
        } catch (IllegalArgumentException ex) {
            throw new WebApplicationException(ex.getMessage(), 400);
        }
    }

    @DELETE
    @Path("/remove")
    public void removeFriend(@QueryParam("playerId") String playerId,
                             @QueryParam("friendId") String friendId) {
        enforceNotBanned();
        if (playerId == null || playerId.isBlank() || friendId == null || friendId.isBlank()) {
            throw new WebApplicationException("playerId and friendId are required", 400);
        }
        boolean removed = friendshipRepository.remove(playerId, friendId);
        if (!removed) {
            throw new WebApplicationException("Friendship not found", 404);
        }

        GameSocket.emitFriendRemoved(playerId, friendId);
    }

    @GET
    @Path("/requests/incoming/count")
    public long incomingCount(@QueryParam("playerId") String playerId) {
        enforceNotBanned();
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

    private FriendGiftDTO toDTO(FriendGift g) {
        return new FriendGiftDTO(
                g.getId(),
                g.getFromPlayerId(),
                g.getToPlayerId(),
                g.getStatus(),
                g.getCreatedAt(),
                g.getClaimedAt()
        );
    }
}
