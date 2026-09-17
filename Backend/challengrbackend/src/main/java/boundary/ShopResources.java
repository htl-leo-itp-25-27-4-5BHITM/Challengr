package boundary;

import control.PlayerRepository;
import control.ShopRepository;
import entity.Player;
import entity.PlayerItem;
import entity.ShopItem;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.util.List;

@Path("/api/shop")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class ShopResources {

    @Inject
    ShopRepository shopRepository;

    @Inject
    PlayerRepository playerRepository;

    @GET
    @Path("/items")
    public List<ShopItem> getItems() {
        return shopRepository.getAllItems();
    }

    @GET
    @Path("/players/{playerId}/items")
    public List<PlayerItemDTO> getOwnedItems(@PathParam("playerId") String playerId) {
        return shopRepository.getOwnedItems(playerId).stream()
                .map(pi -> new PlayerItemDTO(pi.getItem().getCode(), pi.getQuantity()))
                .toList();
    }

    @POST
    @Path("/players/{playerId}/purchase")
    @Transactional
    public Response purchase(@PathParam("playerId") String playerId, PurchaseRequest request) {
        if (request == null || request.itemCode == null || request.itemCode.isBlank()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new PurchaseResultDTO(false, "itemCode fehlt", 0, null, 0))
                    .build();
        }

        Player player = playerRepository.findById(playerId);
        if (player == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new PurchaseResultDTO(false, "Spieler nicht gefunden", 0, request.itemCode, 0))
                    .build();
        }

        ShopItem item = shopRepository.findByCode(request.itemCode);
        if (item == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new PurchaseResultDTO(false, "Item nicht gefunden", player.getPoints(), request.itemCode, 0))
                    .build();
        }

        if (player.getPoints() < item.getPrice()) {
            return Response.status(Response.Status.CONFLICT)
                    .entity(new PurchaseResultDTO(false, "Nicht genug Punkte", player.getPoints(), item.getCode(), 0))
                    .build();
        }

        player.setPoints(player.getPoints() - item.getPrice());
        PlayerItem owned = shopRepository.addOrIncrement(playerId, item);

        return Response.ok(new PurchaseResultDTO(true, "Gekauft", player.getPoints(), item.getCode(), owned.getQuantity()))
                .build();
    }

    public static class PurchaseRequest {
        public String itemCode;

        public PurchaseRequest() {}
    }

    public static class PurchaseResultDTO {
        public boolean success;
        public String message;
        public int remainingPoints;
        public String itemCode;
        public int newQuantity;

        public PurchaseResultDTO() {}

        public PurchaseResultDTO(boolean success, String message, int remainingPoints, String itemCode, int newQuantity) {
            this.success = success;
            this.message = message;
            this.remainingPoints = remainingPoints;
            this.itemCode = itemCode;
            this.newQuantity = newQuantity;
        }
    }

    public static class PlayerItemDTO {
        public String itemCode;
        public int quantity;

        public PlayerItemDTO() {}

        public PlayerItemDTO(String itemCode, int quantity) {
            this.itemCode = itemCode;
            this.quantity = quantity;
        }
    }
}
