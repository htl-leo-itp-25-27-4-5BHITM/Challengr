---
name: figuren-pipeline
description: Bringt einen fertigen Figuren-Entwurf aus der 3D-Toon-Pipeline ins Spiel – Export, SceneKit-Modell, Karten-Animation, Bilder, Asset-Katalog, GameCharacter, Backend-CharacterCatalog, Tests. Verwenden, wenn eine neue Figur (z. B. Kira, Riot, Valka) spielbar werden soll; im Auftrag Name, Freischalt-Regel (z. B. Event-ID oder Trophäen) und Farbe mitgeben.
model: sonnet
tools: Bash, Read, Edit, Write, Grep, Glob
---

Du machst im Challengr-Projekt eine Entwurfs-Figur spielbar. Vorbild ist Frost (Commit `0b21597` – `git show --stat 0b21597`). Nicht committen, nicht pushen – das macht der Aufrufer nach Prüfung.

Pfade: Pipeline `P=~/Developer/ChallengrProjekt/Character3D/pipeline`, App `APP=~/Developer/ChallengrProjekt/Challengr/Swift/Challengr/Challengr`, Backend `~/Developer/ChallengrProjekt/Challengr/Backend/challengrbackend`.

1. Entwurf finden: `$P/char/preview/entwuerfe.js` (Frost, Kira, Riot, Valka) oder `maedels.js` (Vex, Blaze, Nova, Raven). Index = Position in `VARIANTS`.
2. Export (aus `$P/char`): `node preview/export_entwurf.mjs '[[<index>,"<Name>"]]'` → `export/<Name>.json`, `_full.png`, `_avatar.png`. (Für `maedels.js` vorher in `export_entwurf.mjs` die HTML-Seite auf `maedels.html` umstellen und danach zurück.)
3. Aus `$P`: `swift build_scn.swift char/export <Name>`, `mkdir -p out/map_<name> && swift render_map.swift char/export out/map_<name> <Name>`, `swift crop.swift out/map_<name>/<Name>MapSheet.png` (Sheet muss 3072 px breit sein, 16 Bilder).
4. In die App: `$APP/Characters/<Name>.scn`; Imagesets `<Name>`, `<Name>Avatar` (je `sips -Z 512`), `<Name>MapSheet` mit `Contents.json` wie bei `Frost.imageset`; danach `pngquant --force --skip-if-larger --quality 70-95`.
5. Code:
   - `$APP/Logic/GameCharacter.swift`: neuer `case`, in jedem `switch` (displayName, tagline, requirement, sceneName, themeColor).
   - Backend `src/main/java/control/CharacterCatalog.java`: `new Entry("<id>", "<Name>", Requirement.…, …)` – gleiche ID wie in der App.
   - Tests mit Figurenlisten anpassen: `Swift/Challengr/ChallengrTests/CharacterUnlockTests.swift`, Backend `src/test/java/boundary/CharacterResourceTest.java` (Liste + Anzahl).
6. Prüfen: App bauen (`xcodebuild -project Swift/Challengr/Challengr.xcodeproj -scheme Challengr -destination 'platform=iOS Simulator,name=iPhone 17' build`), Backend-Test `CharacterResourceTest` laufen lassen.

Antwort kurz auf Deutsch: geänderte/neue Dateien, Größe von `.scn` und Map-Sheet, Build/Test-Ergebnis, offene Fragen (z. B. Event noch anlegen).
