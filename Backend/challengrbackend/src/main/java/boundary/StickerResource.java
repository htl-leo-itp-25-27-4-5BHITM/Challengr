package boundary;

import control.PlayerRepository;
import control.StickerCatalog;
import control.StickerRepository;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.MediaType;
import security.CurrentPlayer;

import java.util.List;
import java.util.Set;

/** Eigene Sticker-Sammlung fürs Album und die Emote-Auswahl, dazu Album-Stufen und das Sticker-Paket. */
@Path("/api/stickers")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
public class StickerResource {

    @Inject
    CurrentPlayer me;

    @Inject
    StickerRepository stickers;

    @Inject
    PlayerRepository players;

    /** count = so oft noch verschickbar, total = so oft insgesamt bekommen */
    public record StickerStockDTO(String stickerId, int count, int total) {}

    public record StageDTO(int found, int coins, boolean goldFrame, boolean claimed) {}

    public record AlbumDTO(int found, int coins, int packPrice, List<StageDTO> stages) {}

    public record PackDTO(List<String> stickers, int coins, int price) {}

    @GET
    public List<StickerStockDTO> mine() {
        return stickers.listWithStarterPack(me.id()).stream()
                .map(s -> new StickerStockDTO(s.getStickerId(), s.getAmount(), s.getReceivedTotal()))
                .toList();
    }

    /** Album-Stufen (5, 10, 15 gefunden → Coins; alle → goldener Rahmen) */
    @GET
    @Path("/album")
    public AlbumDTO album() {
        stickers.listWithStarterPack(me.id());
        return albumOf(me.id());
    }

    @POST
    @Path("/album/{found}/claim")
    public AlbumDTO claimStage(@PathParam("found") int found) {
        stickers.claimStage(me.id(), found);
        return albumOf(me.id());
    }

    /** Sticker-Paket für Coins: ein paar zufällige Sticker */
    @POST
    @Path("/pack")
    public PackDTO buyPack() {
        List<String> got = stickers.buyPack(me.id());
        return new PackDTO(got, players.findById(me.id()).getPoints(), StickerCatalog.PACK_PRICE);
    }

    /** Freunde, denen dieser Sticker im Album noch fehlt (beim gezielten Verschenken) */
    @GET
    @Path("/{stickerId}/friends-missing")
    public List<String> friendsMissing(@PathParam("stickerId") String stickerId) {
        if (!StickerCatalog.FALLBACK.containsKey(stickerId)) throw new WebApplicationException("Unbekannter Sticker", 404);
        return stickers.friendsMissing(me.id(), stickerId);
    }

    private AlbumDTO albumOf(String playerId) {
        Set<Integer> claimed = stickers.claimedStages(playerId);
        List<StageDTO> stages = StickerCatalog.STAGES.stream()
                .map(s -> new StageDTO(s.found(), s.coins(), s.goldFrame(), claimed.contains(s.found())))
                .toList();
        return new AlbumDTO(stickers.foundCount(playerId), players.findById(playerId).getPoints(), StickerCatalog.PACK_PRICE, stages);
    }
}
