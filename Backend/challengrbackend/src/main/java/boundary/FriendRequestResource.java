package boundary;

import io.quarkus.security.Authenticated;
import security.CurrentPlayer;
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
@Authenticated // A2: alles nur im eigenen Namen
public class FriendRequestResource {

    @Inject
    CurrentPlayer me;

    @Inject
    control.BlockRepository blocks;

    @Inject
    FriendRequestRepository friendRequestRepository;

    @Inject
    FriendshipRepository friendshipRepository;

    @Inject
    FriendGiftRepository friendGiftRepository;

    @Inject
    BanEnforcementService banEnforcement;

    private void enforceNotBanned() {
        banEnforcement.assertNotBanned(me.id());
    }

    @POST
    @Path("/requests")
    public FriendRequestDTO createRequest(FriendRequestCreateDTO dto) {
        enforceNotBanned();
        if (dto == null) {
            throw new WebApplicationException("Missing body", 400);
        }
        me.requireSelf(dto.fromPlayerId());
        if (blocks.blockedEitherWay(dto.fromPlayerId(), dto.toPlayerId())) {
            throw new WebApplicationException("Dieser Spieler ist nicht erreichbar", 403);
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
        me.requireSelf(playerId);
        return friendRequestRepository.findOutgoing(playerId).stream().map(this::toDTO).toList();
    }

    @GET
    @Path("/requests/incoming")
    public List<FriendRequestDTO> incoming(@QueryParam("playerId") String playerId) {
        if (playerId == null || playerId.isBlank()) {
            throw new WebApplicationException("playerId is required", 400);
        }
        me.requireSelf(playerId);
        return friendRequestRepository.findIncoming(playerId).stream().map(this::toDTO).toList();
    }

    @POST
    @Path("/requests/{id}/accept")
    public FriendRequestDTO accept(@PathParam("id") Long id) {
        enforceNotBanned();
        requireRecipient(id);
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
        requireRecipient(id);
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
        me.requireSelf(playerId);
        return friendshipRepository.listFriendIds(playerId).stream().map(FriendDTO::new).toList();
    }

    @POST
    @Path("/gifts")
    public FriendGiftDTO createGift(FriendGiftCreateDTO dto) {
        enforceNotBanned();
        if (dto == null) {
            throw new WebApplicationException("Missing body", 400);
        }
        me.requireSelf(dto.fromPlayerId());
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
        me.requireSelf(playerId);
        return friendGiftRepository.findIncomingPending(playerId).stream().map(this::toDTO).toList();
    }

    @POST
    @Path("/gifts/{id}/claim")
    public FriendGiftDTO claimGift(@PathParam("id") Long id, @QueryParam("playerId") String playerId) {
        enforceNotBanned();
        if (playerId == null || playerId.isBlank()) {
            throw new WebApplicationException("playerId is required", 400);
        }
        me.requireSelf(playerId);
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
        me.requireSelf(playerId);
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
        me.requireSelf(playerId);
        return friendRequestRepository.findIncoming(playerId).size();
    }

    /** Annehmen/Ablehnen darf nur der Empfänger der Anfrage. */
    private void requireRecipient(Long requestId) {
        FriendRequest request = friendRequestRepository.findById(requestId);
        if (request == null) {
            throw new WebApplicationException("Request not found", 404);
        }
        me.requireSelf(request.getToPlayerId());
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
