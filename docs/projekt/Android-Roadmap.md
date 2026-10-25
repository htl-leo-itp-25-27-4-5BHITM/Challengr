# Android-Roadmap für Challengr

Stand: **25.10.2026** (ersetzt die Fassung vom 30.06.2026). Referenz ist die iOS-App in `Swift/Challengr`
(Build `2610241214`) und das Backend auf `https://it220257.cloud.htl-leonding.ac.at`.

**Ziel:** Eine native Android-App, mit der Android-Schüler gegen iPhone-Spieler antreten – gleiche Karte, gleiche Liga,
gleiche Challenges, faire Messungen. Erst eine spielbare Version für den Schultest, danach Gleichstand mit iOS.

**Schätzung** (im bisherigen Arbeitstempo): spielbare Version **3–4 Wochen**, voller Gleichstand inkl. 3D **6–8 Wochen**.
Der Engpass ist nicht das Programmieren, sondern Testen auf verschiedenen echten Android-Geräten und Google-Play-Fristen.

---

## 1. Was bleibt, was neu kommt

| Bereich | Android | Anmerkung |
|---|---|---|
| Backend (Quarkus), Datenbank, Dashboard | **unverändert** | dieselben REST-Endpunkte und dasselbe WebSocket-Protokoll |
| Login (Keycloak, Realm `challengr`) | neuer Client `challengr-android` | sonst gleich (PKCE, `offline_access`) |
| Spiellogik (Trophäen, Ränge, Aufgaben, Events, Auswertung) | **am Server** | App zeigt nur an |
| Cartoon-Karte | MapLibre Android | **`ToonMapStyle.json` 1:1 übernehmen** |
| Figuren auf der Karte (Sprite-Sheets `*MapSheet.png`), Avatare, Sounds, Logo | übernehmen | Assets aus `Swift/Challengr/Challengr/Assets.xcassets` und `Sounds/` |
| App-Code (~20.000 Zeilen SwiftUI) | **neu in Kotlin** | Struktur kann 1:1 gespiegelt werden |
| 3D (SceneKit `.scn`) | **neu** | Figuren direkt aus der three.js-Pipeline als `.glb` exportieren (`Character3D/pipeline`) |

---

## 2. Leitentscheidungen

- **Kotlin + Jetpack Compose + Material 3**, Mindestversion Android 8 (API 26), Ziel aktuelle API.
- **Package / Application-ID:** `com.challengrapp.challengr` (wie die iOS-Release-Bundle-ID). Keine Schule im Namen.
- **Netzwerk:** Retrofit oder Ktor + `kotlinx.serialization`, WebSocket über OkHttp.
- **Login:** AppAuth-Android (PKCE), Redirect `com.challengrapp.challengr:/callback`, Scope `openid profile email offline_access`.
  Refresh-Token in Android Keystore / EncryptedSharedPreferences („angemeldet bleiben“ wie `TokenStore` auf iOS).
- **Karte:** MapLibre Native Android mit dem Challengr-Stil (OpenFreeMap-Kacheln). Kein Google Maps nötig.
  Rückfall bei nicht erreichbarem Kartenserver wie auf iOS (`ToonMapHealth`: nach 8 + 12 s prüfen, ob Kartendaten sichtbar sind).
- **3D später:** SceneView/Filament mit `.glb`. In der ersten Version Quiz-Show und Figurenwahl in 2D (gerenderte Bilder gibt es schon).
- **Liegestütze:** ML Kit Face Detection (Gesichtsgröße ≈ Abstand) statt ARKit; gleiche Regel: unter 25 cm runter, über 35 cm hoch = 1.

---

## 3. Was auf Android exakt gleich sein muss (Fairness iPhone ↔ Android)

### 3.1 Gemeinsamer „Zufall“ pro Battle — `Logic/ChallengeSeed.swift`
Land, Kompass-Zielwinkel, Wartezeiten des Reaktions-Tests und Zielzeit kommen aus der **Battle-Nummer**, damit beide
Spieler dasselbe bekommen. Android muss den Algorithmus **bitgenau** nachbauen (Kotlin `ULong`, Überlauf wie `&*`/`&+`):

```
state = battleId.toULong() * 0x9E3779B97F4A7C15 + salt + 0x12345678
next(): state += 0x9E3779B97F4A7C15
        z = state; z = (z xor (z ushr 30)) * 0xBF58476D1CE4E5B9
        z = (z xor (z ushr 27)) * 0x94D049BB133111EB
        return z xor (z ushr 31)
int(range)    = lower + (next() % count)
double(range) = lower + (next() % 1_000_000) / 1_000_000.0 * (upper - lower)
```
- Salt 1: Kompass-Zielwinkel `int(0..<360)`
- Salt 2: Land = `Country.all[int(0..<count)]` – **Liste in exakt derselben Reihenfolge** übernehmen (28 Länder mit Hauptstadt-Koordinaten)
- Salt 3: Reaktions-Test 3 Wartezeiten `double(1.5...4.0)` s
- Salt 4: Zielzeit `[5, 6, 7, 8, 10][int(0..<5)]` s
- Pflicht: **Kreuztest** – für Battle-IDs 1…100 müssen iOS und Android dieselben Werte liefern (Werte aus einem iOS-Unit-Test als Tabelle übernehmen).

Richtung zur Hauptstadt: Großkreis-Anfangskurs (`Country.bearing`), Abweichung = kleinster Winkel 0–180°.

### 3.2 Messungen vergleichbar machen
| Challenge | iOS | Android | Risiko |
|---|---|---|---|
| Kompass / Länder-Kompass | `trueHeading` | Rotation-Vector-Sensor + `GeomagneticField`-Deklination → **geografischer** Norden | Kalibrierung, Kalibrier-Hinweis anzeigen |
| Sprint | GPS-Strecke in 15 s | Fused Location, gleiche Glättung | GPS-Genauigkeit je Gerät |
| Schrei-Challenge | Mikrofon-Pegel | `AudioRecord`-Pegel | **Mikrofone unterschiedlich laut** → vor Liga-Einsatz mit beiden Geräten nebeneinander abgleichen, sonst iOS↔Android nur im Friendly |
| Schütteln | CoreMotion-Score | Beschleunigungssensor, gleiche Formel | Formel aus `MotionManager.swift` übernehmen |
| Reaktions-Test / Zeitgefühl | Bildschirm-Tipp | gleich | Touch-Latenz minimal unterschiedlich – akzeptabel |
| Liegestütze | ARKit-Gesichtsabstand | ML Kit | Schwellen am Gerät justieren |

### 3.3 Erklär-Bildschirm vor jeder gemessenen Challenge
Gleiche Texte wie `Views/ChallengeIntro.swift`, „Los geht's“ oder automatisch nach **20 s**, danach Bereit-Countdown
**3 s** (Liegestütze **5 s**). Achtung iOS-Fehler aus Build `2610241107`: Auto-Start- und Countdown-Timer **getrennt** halten.

---

## 4. Schnittstellen (Stand 25.10.)

Alle Aufrufe mit `Authorization: Bearer <Keycloak-Token>`; Spieler-ID = Token-Claim `sub`. Fremde IDs → 403.

**REST (App-relevant):**
- Spieler: `POST /api/players` (anlegen), `PUT /api/players` (Position), `GET/PUT /api/players/{id}`, `PUT /{id}/name`,
  `PUT /{id}/visibility`, `GET /{id}/profile`, `/{id}/stats`, `/{id}/battles`, `/{id}/characters`, `PUT /{id}/character`,
  `GET /api/players/nearby` (Header `X-Nearby-Total`), `GET /api/players/search?q=`, `DELETE /api/players/me`
- Liga/Meta: `GET /api/ranks`, `GET /api/leaderboard`, `GET /api/quests`, `POST /api/quests/daily/{id}/claim`,
  `POST /api/quests/events/{id}/claim`, `GET /api/announcement` (204 = keine)
- Orte: `GET /api/hotspots`, `POST /api/hotspots/{id}/checkin` (403 zu weit, 409 schon heute, 429 Tageslimit Orte)
- Freunde: `/api/friends/requests` (+ `/incoming`, `/outgoing`, `/{id}/accept|decline`), `/api/friends/list`, `/api/friends/remove`
- Sicherheit: `POST /api/safety/blocks/{id}`, `DELETE …`, `GET /api/safety/blocks`, `POST /api/safety/reports/{id}`
- Quiz: `POST /api/quiz/questions/{id}/report` (`FALSCHE_ANTWORT|UNKLAR|TIPPFEHLER|SONSTIGES`)
- Challenges: `GET /api/challenges`, `/api/challenges/categories` (für Friendly-Auswahl)

**WebSocket `wss://…/ws/game`** (Login beim Upgrade per Token):
- App → Server: `create-battle`, `update-battle-status`, `battle-answer`, `quiz-answer`, `friendly-finished`, `send-emote`,
  Messwerte `sprint-result {distance}`, `loudness-result {loudness}`, `compass-result {distance}`, `shake-result {shakes}`,
  `pushup-result {reps}`, `country-result {deviation}`, `reaction-result {ms}`, `timing-result {ms}`
- Server → App: `battle-requested`, `battle-updated`, `battle-rejected`, `battle-running`, `battle-pending`, `battle-result`
  (mit `metrics`, Trophäen, Teilnehmern), `battle-question`, `battle-answer-feedback`, `quiz-question`, `quiz-round-result`,
  `quiz-opponent-answered`, `opponent-finished`, `player-position-updated`, `emote`, `friend-request-created|updated`, `friend-removed`

Welcher Bildschirm zu welcher Challenge gehört: `Logic/BattleScreen.swift` – erkannt am **Textanfang** der Challenge
(z. B. `Länder-Kompass`, `Reaktions-Test`, `Zeitgefühl`; Länder-Kompass **vor** „kompass“ prüfen).

---

## 5. Phasen

| # | Phase | Dauer | Fertig, wenn … |
|---|---|---|---|
| 0 | Vorbereitung | 1 Tag | Keycloak-Client `challengr-android` angelegt (Redirect wie oben); Google-Play-Konto (25 $); 2–3 Test-Geräte (verschiedene Hersteller) |
| 1 | Grundgerüst + Login | 4 Tage | App startet, Login mit PKCE, bleibt angemeldet, Lade-Screen, Onboarding mit Datenschutz/Alter ab 14, Spieler wird angelegt |
| 2 | Karte | 5 Tage | Cartoon-Karte mit fester Neigung 55°, Drehen (1 Finger) und Zoomen (200 m–2,5 km), Spieler bleibt mittig, eigene Figur + Gegner (Sprites), Hotspots/Orte mit Check-in, Kompass, Tag/Nacht, Münz-Menü |
| 3 | Battle-Ablauf | 4 Tage | Herausfordern (Liga Quiz / Liga Real-Life / Friendly), Anfragen annehmen/ablehnen, Warten, Ergebnis-Screens mit Messwerten, Aufgeben, Emotes |
| 4 | Gemessene Challenges | 4 Tage | Erklär-Bildschirm + Sprint, Schrei, Kompass, Schütteln, Check-in-Spot, Länder-Kompass, Reaktions-Test, Zeitgefühl; Kreuztest der Seeds grün |
| 4b | Liegestütze | 2 Tage | ML Kit zählt zuverlässig auf 2 Geräten |
| 5 | Quiz-Show (2D) | 2 Tage | 4 Fragen à 15 s, Tempo-Punkte, Auflösung, „Frage melden“ |
| 6 | Rund ums Spiel | 6 Tage | Profil, Freunde (Suche, Karte, QR), Freundesprofil, Rangliste, Trophy Road mit Rekord, Aufgaben + Events, Figurenwahl (2D), Einstellungen (Töne, Mitteilungen, unsichtbar, Name, Karte), Melden/Blockieren, Konto löschen, Ankündigungs-Banner, Sounds |
| 7 | Test + Veröffentlichung | ~1 Woche (parallel) | Geschlossener Test bei Google Play läuft, Feedback-Weg steht |
| 8 | Später | 1–2 Wochen | Quiz-Show im 3D-Studio, 3D-Figurenwahl (SceneView + `.glb`), Shop (wenn er auf iOS öffnet) |

**Spielbare Version für den Schultest = Phasen 0–6.**

---

## 6. Google Play – vorher wissen

- Neues **privates** Entwicklerkonto: Vor der öffentlichen Veröffentlichung muss die App **14 Tage lang mit mindestens 12 Testern**
  im geschlossenen Test laufen. Für den Schultest reicht der **interne Test** (bis 100 Tester per E-Mail-Liste) oder ein geschlossener Test mit Link.
- **Konto löschen**: Google verlangt zusätzlich eine **Web-Möglichkeit** zum Löschen (z. B. Seite auf dem Dashboard-Server, die
  auf `DELETE /api/players/me` nach Login führt) und die Angabe im Formular „Datensicherheit“.
- Nutzerinhalte (Namen, Emotes): Melden/Blockieren ist Pflicht – gibt es schon.
- Jüngere Nutzer: Zielgruppe ehrlich angeben (13+ bzw. 14+ wie in der App), Datenschutzerklärung `/datenschutz.html` verlinken.

---

## 7. Server-Änderungen, die für Android sinnvoll sind

1. **App-Version mitschicken** (Header `X-App-Platform`, `X-App-Version`) und den Liga-Real-Life-Pool danach filtern:
   Am 24.10. bekamen alte iOS-Builds neue Challenges zugelost, die sie nicht kannten. Mit zwei Plattformen wird das häufiger.
2. Optional **Schrei-Challenge iOS↔Android** aus der Liga nehmen, bis die Mikrofone abgeglichen sind.
3. Feedback: Android hat kein TestFlight – Feedback-Knopf in der App (Text + Screenshot) an einen neuen Endpunkt, im Dashboard unter „Feedback“ anzeigen.

---

## 8. Offene Entscheidungen

- Wann starten: vor oder nach dem Test mit den 5. Klassen? (Hängt davon ab, wie viele Schüler Android haben.)
- Wer betreut die Test-Geräte, welche Modelle (mindestens Samsung + ein günstiges Gerät).
- Eigener Server vor dem Play-Store-Start? (Gleiche Frage wie für den App Store.)

---

## 9. Erster Sprint (Phase 0–1)

1. Projekt `Android/Challengr` anlegen (Compose, Navigation, Theme in Challengr-Farben: Rot `#BA1F33`, Dunkel `#1E000E`, Gelb `#FDD006`).
2. Keycloak-Client `challengr-android` anlegen, AppAuth-Login mit PKCE + `offline_access`, Token sicher speichern.
3. `BackendConfig`, HTTP-Client mit Bearer-Token und Erneuerung bei 401, WebSocket-Verbindung.
4. Nach Login `POST /api/players`, Lade-Screen, Onboarding.
5. MapLibre mit `ToonMapStyle.json`, eigener Standort, `PUT /api/players`.
6. `ChallengeSeed` + Länderliste portieren und den Kreuztest mit iOS-Werten schreiben.

**Fertig, wenn:** Login klappt, man bleibt angemeldet, landet auf der Cartoon-Karte, die eigene Figur steht am Standort,
und der Seed-Kreuztest ist grün.
