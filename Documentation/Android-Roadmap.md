# Android-Roadmap fuer Challengr

Stand: 30.06.2026

Ziel: Die Android-App soll funktional gleich zur bestehenden iOS-App werden. Die Webapp ist fuer Android nicht die Grundlage. Android wird als native Kotlin-App gebaut und nutzt dasselbe Quarkus-Backend, dieselben REST-Endpunkte und dasselbe WebSocket-Protokoll wie die Swift-App.

## Leitentscheidung

- Hauptreferenz: `Swift/Challengr`
- Vergleichsreferenz: `Swift Kopie/Challengr`
- Zielplattform: Android native
- Empfohlener Stack: Kotlin, Jetpack Compose, Material 3, AppAuth, Retrofit oder Ktor, OkHttp WebSocket, kotlinx.serialization, CameraX, Android SensorManager
- Backend: bestehendes Challengr-Backend unter `https://it220257.cloud.htl-leonding.ac.at`

## Phase 1: Projektgrundlage

Ziel: Eine lauffaehige Android-App-Struktur mit Navigation, Designbasis und Backend-Konfiguration.

Aufgaben:

- Android-Projekt anlegen, z.B. `Android/Challengr`.
- Package-Struktur definieren:
  - `auth`
  - `network`
  - `models`
  - `websocket`
  - `location`
  - `friends`
  - `battle`
  - `challenges`
  - `profile`
  - `shop`
  - `ui`
- Compose Navigation einrichten.
- App-Theme aus Swift uebernehmen:
  - Challengr Rot
  - Challengr Dunkel
  - Challengr Gelb
  - helle Surface-Flaechen
- Assets uebernehmen:
  - App Icon
  - Player-Bilder
  - Shop-Icons
  - Charakterbilder
  - Sounds
- BackendConfig fuer REST und WebSocket anlegen.

Ergebnis:

- Android-App startet.
- Login-Screen und Platzhalter-Map sind erreichbar.
- Backend-Basis-URL ist zentral konfiguriert.

## Phase 2: Authentifizierung mit Keycloak

Ziel: Android kann sich wie iOS ueber Keycloak anmelden und einen Player im Backend zuordnen.

Aufgaben:

- Keycloak-Client `challengr-android` anlegen.
- Redirect URI definieren, z.B. `challengr://callback`.
- Login mit PKCE ueber AppAuth for Android implementieren.
- Token Exchange implementieren.
- Access Token und ID Token sicher speichern.
- JWT auslesen:
  - `preferred_username`
  - `name`
  - `sub`
  - `player_id`
- Falls `player_id` fehlt: Player ueber Backend erstellen.
- Logout implementieren.
- Session-Restore beim App-Start bauen.

Swift-Referenz:

- `Swift/Challengr/Challengr/Services/KeycloakAuthService.swift`

Ergebnis:

- Nutzer kann sich anmelden.
- Android kennt `playerId`, `playerName` und `keycloakUserId`.
- Nach Login wird die Map geoeffnet.

## Phase 3: REST-API und Datenmodelle

Ziel: Android kann alle benoetigten Backend-Daten laden und schreiben.

Aufgaben:

- Kotlin-DTOs portieren:
  - `PlayerDTO`
  - `PlayerRequestDTO`
  - `ChallengeDTO`
  - `PlayerStatsDTO`
  - `PlayerProfileDTO`
  - `PlayerPointsHistoryDTO`
  - `BattleHistoryDTO`
  - `PlayerLoudnessBestDTO`
  - `FriendRequestDTO`
  - `FriendDTO`
  - `FriendGiftDTO`
  - Rank/Trophy DTOs
- API-Services implementieren:
  - Players
  - Challenges
  - Friends
  - Ranks
- Fehlerbehandlung fuer 4xx/5xx Antworten.
- Loading- und Retry-Zustaende in ViewModels abbilden.

Wichtige Endpunkte:

- `GET /api/challenges/{category}`
- `GET /api/challenges/id/{id}`
- `GET /api/players/{id}`
- `POST /api/players`
- `PUT /api/players/{id}`
- `GET /api/players/nearby`
- `GET /api/players/{id}/points`
- `GET /api/players/{id}/stats`
- `GET /api/players/{id}/battles`
- `GET /api/players/{id}/profile`
- `GET /api/players/{id}/streak`
- `GET /api/players/{id}/points-history`
- `GET /api/players/{id}/loudness-best`
- `PUT /api/players/{id}/loudness-best`
- `GET /api/friends/list`
- `POST /api/friends/requests`
- `GET /api/friends/requests/incoming`
- `GET /api/friends/requests/outgoing`
- `POST /api/friends/requests/{id}/accept`
- `POST /api/friends/requests/{id}/decline`
- `DELETE /api/friends/remove`
- `POST /api/friends/gifts`
- `GET /api/friends/gifts/incoming`
- `POST /api/friends/gifts/{id}/claim`
- `GET /api/ranks`

Swift-Referenzen:

- `Swift/Challengr/Challengr/Model.swift`
- `Swift/Challengr/Challengr/Services/PlayerLocationService.swift`
- `Swift/Challengr/Challengr/Services/ChallengesService.swift`
- `Swift/Challengr/Challengr/Services/FriendsService.swift`
- `Swift/Challengr/Challengr/Views/TrophyRoadView.swift`

Ergebnis:

- Android kann Spieler, Challenges, Freunde, Profil, Punkte und Ranks laden.

## Phase 4: Map, Standort und Nearby Players

Ziel: Die Android-Map entspricht funktional der iOS-Map.

Aufgaben:

- Kartenanbieter festlegen:
  - Google Maps: schnell, stabil, API-Key noetig
  - MapLibre/OpenStreetMap: weniger Google-Abhaengigkeit
- Standortfreigabe implementieren.
- Live-Standort mit Fused Location Provider.
- Eigenen Standort ans Backend senden.
- Spieler in der Naehe ueber `/api/players/nearby` laden.
- Nearby-Spieler als Marker anzeigen.
- Marker-Auswahl mit Spieler-Popup.
- Radius-/Distance-Logik portieren.
- Follow-User-Modus und Recenter-Button bauen.
- WebSocket-Position-Updates in Nearby-Refresh einbauen.

Swift-Referenzen:

- `Swift/Challengr/Challengr/Views/MapView.swift`
- `Swift/Challengr/Challengr/Services/LocationHelper.swift`

Ergebnis:

- Nutzer sieht sich selbst und andere Spieler in der Naehe.
- Position wird regelmaessig aktualisiert.
- Spieler koennen fuer Battles ausgewaehlt werden.

## Phase 5: WebSocket und Battle-Protokoll

Ziel: Android spricht dasselbe Realtime-Protokoll wie iOS.

Aufgaben:

- OkHttp WebSocket fuer `/ws/game?playerId={playerId}` implementieren.
- Automatisches Reconnect mit Backoff.
- Ping/Keepalive.
- Queue fuer Nachrichten, die vor Verbindungsaufbau gesendet werden.
- Nur eine aktive Socket-Verbindung pro Player in der App zulassen.
- Ausgehende Events implementieren:
  - `create-battle`
  - `update-battle-status`
  - `battle-vote`
  - `battle-answer`
  - `sprint-result`
  - `loudness-result`
  - `shake-result`
  - `pushup-result`
  - `compass-result`
  - `camera-result`
- Eingehende Events implementieren:
  - `battle-requested`
  - `battle-created`
  - `battle-updated`
  - `battle-pending`
  - `battle-result`
  - `battle-question`
  - `friend-request-created`
  - `friend-request-updated`
  - `friend-removed`
  - `player-position-updated`

Swift-Referenz:

- `Swift/Challengr/Challengr/WebSocket/GameSocketService.swift`

Backend-Referenz:

- `Backend/challengrbackend/src/main/java/boundary/GameSocket.java`

Ergebnis:

- Android kann Battles erstellen, empfangen, akzeptieren, abschliessen und Ergebnisse empfangen.

## Phase 6: Battle UI und Battle Flow

Ziel: Der komplette Battle-Ablauf funktioniert wie auf iOS.

Aufgaben:

- Challenge-Auswahl-Dialog portieren.
- Eingehende Challenge anzeigen.
- Ausgehende Challenge anzeigen.
- Battle-Screen portieren.
- Statuswechsel abbilden:
  - requested
  - accepted
  - check-in
  - running
  - ready for voting
  - pending
  - result
- Voting-Screen portieren.
- Win-/Lose-Screen portieren.
- Result-Metriken anzeigen.
- Surrender-Flow einbauen.
- Haptisches Feedback ueber Android Vibrator API.
- Sounds ueber Android MediaPlayer/SoundPool.

Swift-Referenzen:

- `Swift/Challengr/Challengr/Views/ChallengeDialogView.swift`
- `Swift/Challengr/Challengr/Views/BattleView.swift`
- `Swift/Challengr/Challengr/Views/BattleVotingView.swift`
- `Swift/Challengr/Challengr/Views/BattleWinView.swift`
- `Swift/Challengr/Challengr/Views/BattleLoseView.swift`
- `Swift/Challengr/Challengr/BattleResultModels.swift`

Ergebnis:

- Zwei Android-Clients koennen einen kompletten Battle durchspielen.
- Android und iOS koennen gegeneinander spielen.

## Phase 7: Challenge-Typen

Ziel: Alle iOS-Challenges werden auf Android umgesetzt.

### Wissen

Aufgaben:

- Frage und Antwortmoeglichkeiten anzeigen.
- Antwort per `battle-answer` senden.
- Ergebnis vom Backend empfangen.

Swift-Referenz:

- `Swift/Challengr/Challengr/Views/KnowledgeBattleView.swift`

### Sprint

Aufgaben:

- Countdown.
- GPS-Strecke messen.
- Ergebnis per `sprint-result` senden.

Swift-Referenz:

- `Swift/Challengr/Challengr/Views/SprintChallengeView.swift`

### Lautstaerke

Aufgaben:

- Mikrofon-Berechtigung.
- Lautstaerke messen.
- Bestwert laden und aktualisieren.
- Ergebnis per `loudness-result` senden.

Swift-Referenzen:

- `Swift/Challengr/Challengr/Views/LoudnessChallengeView.swift`
- `Swift/Challengr/Challengr/Services/SoundMeter.swift`

### Shake

Aufgaben:

- Beschleunigungssensor auslesen.
- Shake-Zaehler implementieren.
- Ergebnis per `shake-result` senden.

Swift-Referenzen:

- `Swift/Challengr/Challengr/Views/ShakeChallengeView.swift`
- `Swift/Challengr/Challengr/Services/MotionManager.swift`

### Compass

Aufgaben:

- Rotation Vector oder Magnetometer nutzen.
- Zielrichtung und Distanz berechnen.
- Ergebnis per `compass-result` senden.

Swift-Referenz:

- `Swift/Challengr/Challengr/Views/CompassChallengeView.swift`

### Kamera/Farbe

Aufgaben:

- CameraX Preview.
- Live-Bildanalyse.
- Farbziel erkennen.
- Ergebnis per `camera-result` senden.

Swift-Referenz:

- `Swift/Challengr/Challengr/Views/CameraChallengeView.swift`

### Pushups

Aufgaben:

- Android-Ersatz fuer ARKit festlegen.
- Empfohlen: ML Kit Pose Detection oder MediaPipe.
- Pose-Erkennung testen.
- Wiederholungen zaehlen.
- Ergebnis per `pushup-result` senden.

Swift-Referenz:

- `Swift/Challengr/Challengr/Views/PushupChallengeView.swift`

Risiko:

- Pushups sind der groesste Android-Portierungsaufwand, weil iOS ARKit nutzt und Android dafuer eine andere Technologie braucht.

Ergebnis:

- Alle Challenge-Typen sind auf Android verfuegbar.

## Phase 8: Freunde, QR und Einladungen

Ziel: Social-Funktionen wie auf iOS.

Aufgaben:

- Freundesliste portieren.
- Eingehende und ausgehende Anfragen.
- Anfrage senden, akzeptieren, ablehnen.
- Freund entfernen.
- Gifts senden und claimen.
- QR-Code fuer Invite erzeugen.
- QR-Code scannen.
- Deep Links fuer Invite-Dateien/URLs einrichten.
- Friend-Realtime-Events vom WebSocket verarbeiten.

Swift-Referenzen:

- `Swift/Challengr/Challengr/Views/FriendsListView.swift`
- `Swift/Challengr/Challengr/Views/FriendInviteQRView.swift`
- `Swift/Challengr/Challengr/Views/FriendInviteScannerView.swift`
- `Swift/Challengr/Challengr/Services/FriendInviteTransfer.swift`
- `Swift/Challengr/Challengr/ViewModels/FriendsViewModel.swift`

Ergebnis:

- Android-Nutzer koennen iOS-Nutzer als Freunde hinzufuegen und umgekehrt.

## Phase 9: Profil, Avatar und Trophy Road

Ziel: Profil- und Progression-Systeme wie auf iOS.

Aufgaben:

- Eigenes Profil portieren.
- Friend Profile portieren.
- Punkte, Stats, Battle-History, Badges, Streak anzeigen.
- Avatar-Auswahl portieren.
- Avatar lokal speichern.
- Trophy Road mit Backend-Ranks anzeigen.
- Profilstatus und Badges laden.

Swift-Referenzen:

- `Swift/Challengr/Challengr/Views/UserProfileView.swift`
- `Swift/Challengr/Challengr/Views/FriendProfileView.swift`
- `Swift/Challengr/Challengr/Views/ProfileContainerView.swift`
- `Swift/Challengr/Challengr/Views/AvatarCustomization.swift`
- `Swift/Challengr/Challengr/Views/CharacterEditorSheet.swift`
- `Swift/Challengr/Challengr/Views/TrophyRoadView.swift`

Ergebnis:

- Android zeigt denselben Progressionsstand wie iOS.

## Phase 10: Shop und Items

Ziel: Shop-Ansicht und Item-Darstellung wie auf iOS.

Aufgaben:

- Shop UI portieren.
- Item-Kategorien und Rarity portieren.
- Shop-Assets uebernehmen.
- Coins/Punkte sichtbar machen.
- Falls Backend-Kauf-Logik fehlt: Shop zuerst als Anzeige bauen.
- Spaeter Kauf- und Inventarlogik mit Backend ergaenzen.

Swift-Referenz:

- `Swift/Challengr/Challengr/Views/ShopView.swift`

Ergebnis:

- Android-Shop ist visuell und funktional auf Stand der iOS-App.

## Phase 11: Settings, Permissions und Polishing

Ziel: Android fuehlt sich komplett und stabil an.

Aufgaben:

- Settings-Screen portieren.
- Logout.
- Berechtigungsdialoge sauber fuehren:
  - Standort
  - Kamera
  - Mikrofon
  - Bewegung/Sensoren
  - Benachrichtigungen, falls spaeter Push kommt
- Fehlerzustaende nutzerfreundlich anzeigen.
- Loading States.
- Empty States.
- Offline-/Reconnect-Hinweise.
- UI auf kleinen und grossen Android-Geraeten testen.

Swift-Referenz:

- `Swift/Challengr/Challengr/Views/SettingsView.swift`

Ergebnis:

- Android-App ist alltagstauglich bedienbar.

## Phase 12: Tests und Release

Ziel: Android ist bereit fuer echte Tests und spaeter Play Store.

Aufgaben:

- Unit Tests fuer DTOs, API Parsing und WebSocket-Event-Parsing.
- ViewModel Tests.
- Manuelle Tests mit zwei Android-Geraeten.
- Crossplay-Test Android gegen iOS.
- Sensor-Tests auf echten Geraeten.
- Permission-Testmatrix.
- Netzwerk-Testmatrix:
  - WLAN
  - mobile Daten
  - Verbindungsabbruch
  - App im Hintergrund
- Play Store Vorbereitungen:
  - App-ID
  - Signing
  - Datenschutzangaben
  - Standort-/Kamera-/Mikrofon-Begruendungen
  - interne Testgruppe

Ergebnis:

- Android-App kann in einen internen Test-Track.

## Prioritaeten

P0:

- Projektgrundlage
- Keycloak Login
- Player-Zuordnung
- REST-Grundlage
- Map und Standort
- WebSocket
- Battle Flow

P1:

- Wissen
- Sprint
- Lautstaerke
- Shake
- Compass
- Kamera/Farbe
- Freunde
- Profil
- Trophy Road

P2:

- Pushups
- Shop mit voller Kauf-/Inventarlogik
- Polishing
- Release-Vorbereitung

## Offene Entscheidungen

- Kartenanbieter: Google Maps oder MapLibre/OpenStreetMap.
- Pushup-Technologie: ML Kit Pose Detection oder MediaPipe.
- Android-Projektname und Package-ID.
- Ob `Swift Kopie` noch aktive Features enthaelt, die in `Swift` fehlen.

## Empfohlener erster Sprint fuer Android

Ziel: Login bis Map.

Tasks:

- Android-Projekt anlegen.
- Compose Navigation einrichten.
- Theme und Basis-UI anlegen.
- Keycloak Android-Client konfigurieren.
- Login mit PKCE implementieren.
- Player nach Login erstellen/aufladen.
- Backend DTOs fuer Player portieren.
- Leere Map mit Standortpermission anzeigen.
- Eigenen Standort laden und ans Backend senden.

Definition of Done:

- App startet auf Android.
- Login funktioniert.
- PlayerId wird erzeugt oder geladen.
- Nutzer landet nach Login auf der Map.
- Eigener Standort wird angezeigt und ans Backend geschickt.
