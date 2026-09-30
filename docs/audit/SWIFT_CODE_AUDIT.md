# SWIFT CODE AUDIT – Challengr iOS (Phase 2)

> Gegenstand: `Swift/Challengr/Challengr` (54 Dateien), Commit `8eccb7f`. Das Backend wurde mitgeprüft, soweit es die App direkt betrifft (API-Verträge, Sicherheit).
> **Einstufung jedes Befunds:**
> - **DEFEKT** – durch einen echten Test oder eine echte Anfrage bestätigt
> - **RISIKO** – statisch im Code nachgewiesen, aber nicht durch einen Test ausgelöst
> - **HYPOTHESE** – plausibel, nicht überprüfbar in dieser Umgebung
> - **VERBESSERUNG** – optional
>
> Schwere: **kritisch / hoch / mittel / niedrig**.

---

## 1. Compiler und Sprachkonfiguration

| Einstellung | Wert | Bewertung |
|---|---|---|
| `SWIFT_VERSION` | 5.0 | Swift-5-Modus: Concurrency-Verstöße sind nur Warnungen |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | MainActor | Alle Typen sind implizit `@MainActor`, auch Services, deren Callbacks auf Hintergrund-Threads laufen |
| `SWIFT_STRICT_CONCURRENCY` | nicht gesetzt (minimal) | Mit `complete` entstehen **58 Meldungen** (`logs/02_strict_concurrency_warnings.txt`) |
| Warnungen im Standard-Build | **12** Swift-Warnungen (`logs/01_build_warnings.txt`) | 6 × veraltete APIs, 2 × Codable-Property mit Initialwert, 1 × ungenutzte Variable, 1 × Swift-6-Fehler-Vorbote |

**Standard-Warnungen im Detail:**
- `Model.swift:45`, `TrophyRoadView.swift:6`: `let id = UUID()` in `Codable`-Structs wird nie dekodiert, die ID ist bei jedem Laden neu.
- `CameraChallengeView.swift:414-415`: `videoOrientation` ist seit iOS 17 veraltet (Deployment Target ist 17.6), stattdessen `videoRotationAngle` verwenden.
- `MapView.swift:380, 407`, `TrophyRoadView.swift:166`: veraltetes `onChange(of:perform:)`.
- `UserProfileView.swift:194, 216, 246`: `plotAreaFrame` → `plotFrame`.
- `LoudnessChallengeView.swift:236`: `let integral = computeLoudnessIntegral()` ist berechnet, aber nie benutzt (toter Rechenweg).
- `LoudnessChallengeView.swift:295`: MainActor-isolierte `Equatable`-Konformität in nicht-isoliertem Kontext. Das ist **in Swift 6 ein Fehler**.

---

## 2. Befunde nach Bereichen

### 2.1 Spiellogik und Zustand

| ID | Befund | Einstufung | Schwere | Beleg |
|---|---|---|---|---|
| **CA-01** | Eine neue eingehende Anfrage überschreibt `currentBattleId` auch **während eines laufenden Battles**. Aufgeben, „Geschafft“ und Abstimmen gehen dann an die neue Anfrage, das laufende Battle hängt. | **DEFEKT** (GP17) | **hoch** | `MapView.swift:1286` (`currentBattleId = battleId` ohne Prüfung von `activeFullScreen`); Backend-Log `logs/06_GP17_backend_evidence.txt`: `DONE_SURRENDER` für Battle 15 statt 14 |
| **CA-02** | Wissens-Battle: Antworten beide Spieler falsch, gibt es **kein Ergebnis**. Der Client sperrt nach einer Antwort (`isSending = true`), das Backend wertet nur richtige Antworten aus. Das Battle hängt, bis es nach 10 min als `ABANDONED` abgebrochen wird. | **DEFEKT** (GP14) | **hoch** | `KnowledgeBattleView.swift:92`; `GameSocket.handleBattleAnswer` |
| **CA-03** | Spielzustand nur im Speicher: Ein App-Neustart während einer eigenen offenen Anfrage oder eines laufenden Battles verliert den Zustand. Die App lädt offene/laufende Battles nicht vom Server. | **DEFEKT** (FU01, FU02 → BUG-05, BUG-06) | **hoch** | `MapView` hält alles in `@State`; es gibt keinen Endpunkt für „mein aktives Battle“ |
| **CA-04** | Annehmen setzt `activeFullScreen = .battle` **optimistisch**, bevor der Server bestätigt. Wurde die Anfrage gleichzeitig abgebrochen oder ist sie abgelaufen, landet der Spieler in einem Battle, das es nicht gibt. `handleBattleClosed` räumt nur `incomingChallenge` auf, nicht den Vollbild-Battle. | RISIKO | mittel | `MapView.swift:971-980`, `1499-1509` |
| **CA-05** | „Schließen“ in Wissens- und Check-In-Battle verlässt das Battle, **ohne aufzugeben**. Der Gegner wartet dann bis zu 10 min. | RISIKO | mittel | `KnowledgeBattleView.swift:121`, `CheckInSpotView.swift:112` |
| **CA-06** | `PlayerAnnotation.id = UUID()` wird bei jeder Nähe-Abfrage (alle 4 s) neu erzeugt. SwiftUI baut dann alle Pins neu auf. Der Vergleich `selectedPlayer?.id == annotation.id` (Popup ein-/ausblenden) greift nach einer Aktualisierung nie. | RISIKO | niedrig | `MapView.swift:19-20`, `603-609` |
| **CA-07** | `fullScreenCover(isPresented: .constant(...))`: Eine Konstanten-Binding verhindert, dass SwiftUI das Schließen melden kann, z.B. per System-Geste. Der Zustand kann auseinanderlaufen. | RISIKO | niedrig | `MapView.swift:417` |
| **CA-08** | Ergebnis-Screen erscheint über `DispatchQueue.main.asyncAfter(2.5 s)` ohne Abbruchmöglichkeit. Kommt in diesem Fenster ein weiteres Ereignis, überschreibt der verspätete Block den neuen Zustand. | RISIKO | niedrig | `MapView.swift:1389` |
| **CA-09** | Kompass-Challenge startet einen unstrukturierten `Task`, der beim Verlassen der View nicht abgebrochen wird. Das Ergebnis wird trotzdem gesendet. `CompassManager` stoppt die Heading-Updates nie. | RISIKO | niedrig | `CompassChallengeView.swift:159`, `205-213` |

### 2.2 Architektur und Wartbarkeit

| ID | Befund | Einstufung | Schwere | Beleg |
|---|---|---|---|---|
| **CA-10** | **`MapView` ist ein God-Object**: 1 676 Zeilen, ≈ 50 `@State`-Properties, WebSocket-Verdrahtung, Datenladen, Kamera-Steuerung, 6 Overlays, Battle-Routing. Spielzustand als Tupel statt Typen. | RISIKO (Wartbarkeit) | hoch | `MapView.swift` |
| **CA-11** | Toter Code in `MapView`: `battleScreen`, `challengeSheet` (unerreichbar, weil `showChallengeView` nie `true` wird), `locationButton`, `vibrate()`, `opponentVote`; `myVote` wird nur geschrieben. | RISIKO | niedrig | `MapView.swift:166-167, 228, 715, 1141, 1149` |
| **CA-12** | Drei parallele Mechanismen für Freundschaftsanfragen: WebSocket-Events, `FriendsInboxStore`-Polling (60 s), `FriendsListView`-Polling (5 s). Beim Öffnen der Freundesliste starten **zwei `loadAll` gleichzeitig** (`.task` + Polling-Schleife). Freunde werden einzeln nacheinander geladen (N+1). | RISIKO | mittel | `FriendsListView.swift:249-274`, `FriendsViewModel.swift:36-42` |
| **CA-13** | Zusätzliche `LocationHelper`-Instanzen in `SprintChallengeView` und `CheckInSpotView`. Jede startet einen eigenen `CLLocationManager` mit `kCLLocationAccuracyBest` und sendet **bei jedem GPS-Update einen PUT** an das Backend. Nirgends in der App wird `stopUpdatingLocation` aufgerufen. | RISIKO (Akku/Netz) | mittel | `LocationHelper.swift:27-51`, `SprintChallengeView.swift:58`, `CheckInSpotView.swift:60` |
| **CA-14** | Battle-Typ wird am **Text der Challenge** erkannt („Sprint-Challenge“, „Kamera“ …). Wer im Dashboard einen Text umbenennt, ändert damit das Spiel. | RISIKO | mittel | `Logic/BattleScreen.swift` |
| **CA-15** | 62 `print()`-Aufrufe, auch in Release-Builds, unter anderem jede WebSocket-Nachricht. Keine Log-Level (`os.Logger`). | VERBESSERUNG | niedrig | `GameSocketService.swift:255, 376 …` |
| **CA-16** | Einstellung **„Hintergrundmusik“ ohne Funktion**: `isMusicEnabled` wird nirgends gelesen, es gibt keine Musik. | DEFEKT (statisch eindeutig) | niedrig | `SettingsView.swift:8, 23` |
| **CA-17** | Unbenutzte Assets: `basic` (0,9 MB JPG), `character.usdc`, Shop-Bilder ohne „ 1“-Suffix (9 Imagesets, Duplikate). Sound-Dateien: 62, davon 16 benutzt. | VERBESSERUNG | niedrig | Asset-Katalog, `SoundEffect` |
| **CA-18** | **Kein App-Icon**: `AppIcon.appiconset` enthält keine Bilddatei. Auf dem Homescreen und in Mitteilungen erscheint der Platzhalter. Blocker für den App Store. | **DEFEKT** (Screenshot GP19) | hoch | `Assets.xcassets/AppIcon.appiconset/Contents.json` |

### 2.3 Concurrency und Speicher

| ID | Befund | Einstufung | Schwere | Beleg |
|---|---|---|---|---|
| **CA-19** | **Data-Race-Risiko in `GameSocketService`:** Die Klasse ist per Default-Isolation `@MainActor`, aber die Callbacks von `URLSessionWebSocketTask.receive`, `send` und `sendPing` laufen auf der Delegate-Queue von URLSession und verändern dort `webSocketTask`, `pendingMessages`, `reconnectAttempt` und rufen `scheduleReconnect()` / `handleIncoming()` auf. Im Swift-5-Modus wird das nicht erzwungen. | RISIKO (Strict-Concurrency: 17 Meldungen) | hoch | `GameSocketService.swift:118-123, 190-196, 260-274, 363-385`; `logs/02_strict_concurrency_warnings.txt` |
| **CA-20** | Gleiches Muster in `SoundMeter`, `LoudnessChallengeView` (Timer-Closures verändern `@State` und `var remaining`), `KnowledgeBattleView` (NotificationCenter-Closure), `Sprint`/`Shake`/`Pushup` (Timer → MainActor-Methoden). | RISIKO | mittel | Strict-Concurrency-Log |
| **CA-21** | **WebSocket wird beim Logout nicht getrennt.** `MapView.onDisappear` stoppt nur das Polling, `socket.disconnect()` wird nie aufgerufen. Der Socket reconnectet selbstständig (Ownership bleibt bestehen). | **DEFEKT** (SC02 → BUG-09, Backend-Log `logs/09_*`) | mittel | `MapView.swift:665-669`, `GameSocketService.swift:101-165` |
| **CA-22** | `GameSocketService`-Callbacks halten `self` der MapView-Struct (SwiftUI-Value, kein Retain-Cycle im klassischen Sinn). `FriendsInboxStore`-Polling-Task hält `self` schwach. **Keine klassischen Retain-Cycles gefunden.** | geprüft, unkritisch | – | – |

### 2.4 Fehlerbehandlung und Netzwerk

| ID | Befund | Einstufung | Schwere | Beleg |
|---|---|---|---|---|
| **CA-23** | Die meisten REST-Aufrufe prüfen den HTTP-Status nicht (`_ = try await URLSession.shared.data(for:)`, `let (data, _)`). Ein 404/500 wird zum Decoding-Fehler oder still ignoriert. Fehler landen fast überall nur in `print`, **der Nutzer sieht keine Fehlermeldung** (siehe SC07 offline). | RISIKO | mittel | `PlayerLocationService.swift:29, 46`, `KeycloakAuthService.swift:117` |
| **CA-24** | Token-Austausch prüft den HTTP-Status nicht. Eine Keycloak-Fehlerantwort wird als „Token-Fehler: The data couldn’t be read …“ angezeigt, eine unverständliche Meldung. | RISIKO | niedrig | `KeycloakAuthService.swift:117-128` |
| **CA-25** | `preloadChallenges` verschluckt Fehler pro Kategorie. Schlägt das Laden fehl, zeigt der Dialog nur „Challenges werden noch geladen …“, ohne erneuten Versuch. | RISIKO | niedrig | `MapView.swift:1523-1538` |

### 2.5 Force-Unwraps und Crash-Risiken

Wenige, und alle unkritisch:
- `Model.swift:78`: `URL(string: "https://…")!` (konstante URL)
- `Model.swift:96`: `components.url!` (Komponenten aus gültiger URL)
- `AvatarCustomization.swift:48`: `preset(withId: defaultPresetId)!` (konstante Liste)
- `CameraChallengeView.swift:669`: `layer as! AVCaptureVideoPreviewLayer` (per `layerClass` garantiert)
- `MapView.swift:131`: `fatalError` im als `unavailable` markierten `init()`. Durch den Compiler unerreichbar.

In keinem UI-Test ist die App abgestürzt (siehe BUILD_AND_TEST_RESULTS).

---

## 3. Sicherheit und Datenschutz

> Getestet wurde nur gegen das **lokale Audit-Backend** (Kopie des Repo-Backends). Gegen die Produktivumgebung habe ich nichts ausgeführt. Bei den Befunden S-01 bis S-03 ist die Produktivwirkung aus der Konfiguration abgeleitet (statisch).

| ID | Befund | Einstufung | Schwere | Beleg |
|---|---|---|---|---|
| **S-01** | **Die App sendet nie einen Auth-Token.** `accessToken` wird nach dem Login gespeichert, aber in keiner Anfrage benutzt. Die REST-API und der WebSocket identifizieren Spieler nur über die ID in URL bzw. Query. | **DEFEKT** (Code eindeutig, `grep Authorization` = 0 Treffer) | **kritisch** | `KeycloakAuthService.swift:21, 119`; alle Services |
| **S-02** | Das Backend verlangt für **keinen** Endpunkt eine Anmeldung: kein `@Authenticated`/`@RolesAllowed`, Admin-Ressourcen explizit `@PermitAll`, darunter **Ban/Unban**, das Keycloak-Benutzer deaktiviert. | RISIKO (Produktivkonfiguration statisch) | **kritisch** | `AdminBanResource.java:22`, `AdminOverviewResource.java:18`, `AdminErdResource.java:35`, `application.properties` |
| **S-03** | Lokal bestätigt: Ohne Token kann man **den Namen und die Position eines fremden Spielers ändern** (`PUT /api/players/demo-2` → `GEHACKT`). `GET /api/players` liefert **alle Spieler mit genauer Position** und Ban-Status. `GET /api/challenges` liefert die richtigen Wissens-Antworten. | **DEFEKT** (lokal) | **kritisch** | `logs/05_security_rest_unauth.txt` |
| **S-04** | Die Ban-Prüfung liest die Spieler-ID aus einem Header, den der Client selbst mitschickt, und ist dadurch trivial umgehbar. | RISIKO | hoch | `FriendRequestResource.java:40-42` |
| **S-05** | CORS erlaubt `*` zusammen mit Credentials. | RISIKO | mittel | `application.properties` |
| **S-06** | Triviale Standardwerte für DB-Passwort und OIDC-Client-Secret als Fallback, falls die Umgebungsvariable fehlt (Werte hier nicht wiedergegeben). | RISIKO | niedrig | `application.properties:3, 18` |
| **S-07** | **Messwerte werden vom Client ungeprüft übernommen** (Sprint-Distanz, Lautstärke, Liegestütze …). Mit einer eigenen WebSocket-Verbindung lässt sich jedes Battle gewinnen. | RISIKO | hoch | `GameSocket.handleMetricResult` |
| **S-08** | Logout: Der Login nutzt eine persistente Browser-Session (`prefersEphemeralWebBrowserSession = false`), der Logout eine ephemere (`true`). Das Logout erreicht die SSO-Cookies des Logins vermutlich nicht, und der nächste „Anmelden“-Tipp meldet ohne Passwort wieder an. | HYPOTHESE (ohne echtes Keycloak nicht prüfbar) | mittel | `KeycloakAuthService.swift:93, 219` |
| **S-09** | Tokens werden nicht persistiert (kein Keychain). Das ist sicher, aber jeder App-Start verlangt einen neuen Login. Kein Refresh-Token-Handling: Nach Ablauf des Access-Tokens gäbe es Probleme, sobald S-01 behoben ist. | VERBESSERUNG | niedrig | `KeycloakAuthService.swift` |
| **S-10** | Lokale Speicherung: nur `UserDefaults` (Einstellungen, Player-ID-Cache, Onboarding). Keine sensiblen Daten. | geprüft, unkritisch | – | – |
| **S-11** | Positionsdaten: Die WebSocket-Events sind seit dem letzten Stand datenschutzfreundlich (nur Nahbereich, ohne Koordinaten). Der REST-Endpunkt aus S-03 hebt diesen Schutz aber vollständig auf. | DEFEKT (lokal) | hoch | S-03 |

---

## 4. Testbarkeit

- Positiv: Die reine Logik liegt in `Logic/` und ist zu **100 %** abgedeckt. `GameSocketService.handleIncoming` ist direkt testbar (36 %).
- Negativ: Die gesamte übrige Spiellogik sitzt in Views (`MapView`, Battle-Views) und ist ohne UI nicht testbar. Die Services erzeugen `URLSession.shared` direkt, es gibt kein Protokoll zum Austauschen gegen Test-Doubles. Die Gesamtabdeckung liegt bei **3,9 %**.
- Es gibt keine UI-Tests und keine Accessibility-Identifier. Die UI-Tests dieses Audits mussten deshalb über sichtbare Texte und SF-Symbol-Namen navigieren.

## 5. Positiv aufgefallen

- Keine Drittanbieter-Abhängigkeiten, schneller Clean Build (17 s).
- Klare Farb- und Komponentenbasis (`GamePrimaryButton`, `GameCard`, `HudCircleButton`).
- Der Nachrichtenfluss (Anfrage → Annahme → Ergebnis) funktioniert in 16 von 19 End-to-End-Tests fehlerfrei, siehe GAMEPLAY_TEST_REPORT.
- Ergebnis-Zuordnung über Spieler-IDs, Ablehnungs- und Ablauf-Banner sowie Sounds sind konsistent umgesetzt.
