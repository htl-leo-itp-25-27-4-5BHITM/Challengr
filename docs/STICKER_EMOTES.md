# Auftrag: Sticker-Emotes im Spiel

**Für einen neuen Chat.** Lies zuerst `docs/PROJEKT_STAND.md` (Projektstand, Deploy, Stolperfallen). Antworte auf Deutsch.
Committen darfst du selbst, **pushen, auf Leo Cloud deployen und TestFlight-Uploads nur nach Rückfrage**.

## Ziel

Die WhatsApp-Sticker aus dem Fight-Video (Sir Brecht mit Aura usw.) sollen im Spiel **als Emotes** verschickt werden können.
Das geht genau wie die heutigen Emoji-Emotes: auf der Karte über das Spieler-Popup und im Battle an den Gegner.
Ein Chat ist **nicht** gewünscht. Beim Empfänger ploppt der Sticker statt der Emoji-Blase über der Figur auf.

## Woher die Sticker kommen

Die Sticker liegen außerhalb des Repos unter `~/Developer/ChallengrProjekt/Werbevideo/sticker/`:

- `png/01_aura.png` … `20_naechste.png`: 512×512 mit transparentem Hintergrund und weißem Sticker-Rand. **Die nimmst du.**
- `animiert/{aura,gogogo,1hit,oida,crazy,farming}.webp`: animiert, 10 fps, 1,6–2 s lang. Die kommen erst in Phase 2.
- `../sticker/Uebersicht.jpg`: alle 20 auf einen Blick.

| Datei | Figur | Text |
|---|---|---|
| 01_aura | Sir Brecht | +1000 AURA |
| 02_gogogo | Sir Brecht | ゴゴゴ |
| 03_1hit | Sir Brecht | 1 HIT |
| 04_locked | Sir Brecht | LOCKED IN |
| 05_mvp | Sir Brecht | MVP |
| 06_schularbeit | Sir Brecht | NACH DER SCHULARBEIT |
| 07_vorbei | Sir Brecht | NOCH NICHT VORBEI. |
| 08_farming | Sir Brecht | AURA FARMING |
| 09_skillissue | Brecht + Ragnar | SKILL ISSUE |
| 10_oida | Ragnar | OIDA. |
| 11_minusaura | Ragnar | -1000 AURA |
| 12_brodachte | Ragnar | BRO DACHTE 💀 |
| 13_diskussion | Hayato | DISKUSSION BEENDET. |
| 14_baba | Kage | BABA. |
| 15_hue | Kage | HÜ? NIE GSEHN. |
| 16_crazy | Kai | DAS CRAZY |
| 17_1v1 | Kai | 1V1 MICH |
| 18_bigbrain | Merlo | BIG BRAIN 🧠 |
| 19_zauber | Merlo | LERNEN? ICH ZAUBER. |
| 20_naechste | Gruppe | WER IST DER NÄCHSTE? |

**Achtung, Apple-Emojis:** In 12, 18 und 19 sind Apple-Color-Emojis eingebrannt (💀 🧠 ✨). Privat in WhatsApp ist das ok, in einer verteilten App eher nicht.

Die empfohlene Lösung ist, die drei ohne Emoji neu zu rendern:

1. In `Werbevideo/fightvideo/src/sticker.js` die `emoji(L, …)`-Aufrufe der Sticker `brodachte`, `bigbrain` und `zauber` auskommentieren. Sie stehen um Zeile 157, 200 und 207.
2. Dann `cd ~/Developer/ChallengrProjekt/Werbevideo/fightvideo && node sticker.mjs brodachte bigbrain zauber` ausführen. Das braucht Chrome und Homebrew-`webp`.
3. **Vorher** `../sticker/png` sichern, sonst werden die WhatsApp-Versionen überschrieben.

Alternativ lässt du die drei vorerst weg.

## Wie Emotes heute funktionieren

**App (Swift):**

- `Views/MapLiveEffects.swift`:
  - `enum Emotes`: `all` (24 Emojis), `battle` (die ersten 8), `map` (Standard-Kurzwahl) und `visibleSeconds = 2.5`.
  - `struct EmoteEvent`.
  - `struct EmoteBubble`: das Emoji als `Text` in einem weißen Kreis.
- `Views/EmotePicker.swift`:
  - `EmoteFavorites`: Kurzwahl mit 4 Plätzen in UserDefaults. `load` filtert auf `Emotes.all`.
  - `EmotePickerSheet`: Raster mit allen Emotes plus „Kurzwahl bearbeiten“.
- `Views/MapView.swift`:
  - Kurzwahl im Spieler-Popup (ca. Zeile 1193).
  - `sendMapEmote` (ca. 1586).
  - Sheet `emotePickerTarget` (ca. 437).
  - `ownMapEmote`, `ownBattleEmote` und `opponentBattleEmote`.
- `Views/BattleView.swift`: `emoteControl` (ca. 452) ist eine einzeilige Leiste mit `Emotes.battle`. Die Blasen über den Figuren kommen aus `EmoteBubble`.
- `WebSocket/GameSocketService.swift`:
  - `sendEmote(toId:emoji:battleId:)` schickt `{"type":"send-emote","toId","emoji","battleId"?}`.
  - Beim Empfang wird `type == "emote"` zu `onEmote(fromId, emoji, battleId)`.

**Backend:** `Backend/challengrbackend/src/main/java/boundary/GameSocket.java`

- `EMOTES` ist eine Whitelist und muss gleich sein wie `Emotes.all`. Andere Werte werden ignoriert.
- Dazu kommen `EMOTE_COOLDOWN` von 1,5 s und `handleEmote` (ca. Zeile 232–285).
- Blockierte Spieler bekommen nichts (`SafetyResource`).

**Tests:**

- `ChallengrTests/MapFeaturesTests.swift` vergleicht die Liste mit dem Backend und prüft das Parsen.
- `ChallengrTests/LeaderboardAndEmoteTests.swift` testet die Favoriten.
- `Backend/…/src/test/java/boundary/GameSocketTest.java` testet das Backend.

## Vorgeschlagener Umbau

### 1. Protokoll: rückwärtskompatibel

Die alten App-Versionen auf TestFlight dürfen nicht kaputtgehen. Deshalb ist der Sticker ein **zusätzliches Feld**, und `emoji` bleibt als Ersatz drin:

```json
{"type":"send-emote","toId":"…","emoji":"🔥","sticker":"aura","battleId":12}
```

- Das Backend bekommt `STICKERS` als Whitelist. Am besten ist es eine Map von Sticker-ID auf Ersatz-Emoji, z. B. `aura→🔥`, `oida→😤`, `1hit→🥊`, `bigbrain→🧠`, `baba→👋`.
- Bei gültigem `sticker` setzt der Server das passende Ersatz-Emoji selbst und leitet `sticker` mit weiter. Unbekannter Sticker heißt: ignorieren, wie bei Emojis.
- Cooldown und Blockieren gelten unverändert.
- Alte Apps zeigen dann einfach das Ersatz-Emoji. Neue Apps zeigen den Sticker.
- Das **Backend zuerst deployen**, dann die App. Vor dem Deploy ein Backup machen, wie in PROJEKT_STAND beschrieben, und den Nutzer fragen.

### 2. App

- **Assets:**
  - Die PNGs auf **256×256** verkleinern (`sips -Z 256`) und mit `pngquant` komprimieren (ist installiert).
  - Als Imagesets `Sticker_aura` usw. nach `Assets.xcassets/Sticker/` legen. Ein Ordner im Asset-Katalog braucht keine Änderung an der pbxproj.
- **Modell:**
  - Neues `enum Stickers` mit Liste `(id, assetName, label, fallbackEmoji)`. Die Reihenfolge ist wie in der Tabelle.
  - Die IDs müssen gleich sein wie im Backend. Dafür einen Test schreiben, wie `testEmotesMatchTheBackendList`.
  - `EmoteEvent` bekommt ein optionales `sticker`.
  - `onEmote` bzw. das Parsen liest `json["sticker"]`.
  - `sendEmote` bekommt den Parameter `sticker:`.
- **Anzeige:** `EmoteBubble` zeigt bei Stickern das Bild in etwa **90–110 pt** ohne weißen Kreis, weil der Sticker schon einen eigenen Rand hat. Pop-Animation wie bisher, eventuell etwas länger sichtbar (≈ 3 s).
  - Auf der Karte wird die Blase mit 0.7 skaliert (MapView ca. Zeile 966). Prüfen, ob der Sticker dort noch lesbar ist.
- **Auswahl:**
  - Im `EmotePickerSheet` oben einen Umschalter **„Emojis | Sticker“** einbauen. Sticker in einem 3- bis 4-spaltigen Raster mit Bildern.
  - Die Kurzwahl darf auch Sticker enthalten, z. B. als String `"stk:aura"` gespeichert. `EmoteFavorites.load` muss die dann auch zulassen.
  - Im Battle reicht ein zusätzlicher Sticker-Knopf in `emoteControl`, der ein kleines Raster aufklappt. Die Leiste ist bisher einzeilig, also nicht überladen.
- **Barrierefreiheit:** `accessibilityLabel` = Text des Stickers, z. B. „Sticker: Oida“.

### 3. Phase 2 (optional): animierte Sticker

- Die 6 animierten WebP als Data-Asset oder im Bundle mitliefern.
- iOS kann animiertes WebP mit ImageIO abspielen: `CGAnimateImageAtURLWithBlock` bzw. `CGAnimateImageDataWithBlock`, ab iOS 13. Animiertes WebP geht ab iOS 14.
- Die Dateien haben je 260–470 KB. Für die App eventuell kleiner neu exportieren, z. B. 256 px mit `img2webp`. Die Frames liegen in `Werbevideo/sticker/frames/<id>/`.
- Die animierte Version wird nur in der Blase abgespielt. Im Picker reicht das Standbild.

## Fertig, wenn

- Unit-Tests in Swift und Backend sind grün, inklusive der neuen Sticker-Tests:
  - Whitelist stimmt überein.
  - `sticker` wird geparst.
  - Ein unbekannter Sticker wird ignoriert.
  - Das Ersatz-Emoji wird gesetzt.
- Demo mit zwei Simulatoren: Sticker auf der Karte und im Battle senden und empfangen. Dafür gibt es `TestHarness/README.md` und `DemoTests`. Screenshots davon machen.
- `docs/PROJEKT_STAND.md` ist um den Eintrag ergänzt.
- Commit ist gemacht. Danach den Nutzer fragen, ob Push, Deploy und TestFlight-Build erfolgen sollen.
