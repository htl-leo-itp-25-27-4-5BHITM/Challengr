package boundary;

import control.StickerRepository;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import security.CurrentPlayer;

import java.util.List;

/** Eigene Sticker-Sammlung fürs Album und die Emote-Auswahl. */
@Path("/api/stickers")
@Authenticated
@Produces(MediaType.APPLICATION_JSON)
public class StickerResource {

    @Inject
    CurrentPlayer me;

    @Inject
    StickerRepository stickers;

    /** count = so oft noch verschickbar, total = so oft insgesamt bekommen */
    public record StickerStockDTO(String stickerId, int count, int total) {}

    @GET
    public List<StickerStockDTO> mine() {
        return stickers.listWithStarterPack(me.id()).stream()
                .map(s -> new StickerStockDTO(s.getStickerId(), s.getAmount(), s.getReceivedTotal()))
                .toList();
    }
}
