# BUG REPORT – Challengr iOS (Phase 7)

> Konsolidierter Fehlerkatalog. Jeder Eintrag ist entweder **durch einen echten Test bestätigt** (Screenshot/Log) oder als **statisch** gekennzeichnet.
> Geräte: iPhone 17 Pro, iPhone 16e, iPad Pro 11" (M4) – alle iOS 26.0 Simulator, Commit `8eccb7f`.
> Schwere: **kritisch** (Sicherheit/Blocker) · **hoch** (Spiel steckt fest / Release-Blocker) · **mittel** · **niedrig**.

## Übersicht

| ID | Titel | Schwere | Nachweis | Reproduzierbar |
|---|---|---|---|---|
| [BUG-01](#bug-01) | API und WebSocket ohne Authentifizierung | **kritisch** | lokal getestet + statisch | immer |
| [BUG-02](#bug-02) | Anfrage eines Dritten kapert das laufende Battle | **hoch** | UI-Test GP17 + Backend-Log | immer |
| [BUG-03](#bug-03) | Wissens-Battle hängt, wenn beide falsch antworten | **hoch** | UI-Test GP14 | immer |
| [BUG-04](#bug-04) | Dark Mode unbrauchbar (Markenfarben werden weiß) | **hoch** | Screenshot | immer |
| [BUG-05](#bug-05) | Nach Neustart wird die Annahme der eigenen Anfrage ignoriert | **hoch** | UI-Test FU01 | immer |
| [BUG-06](#bug-06) | Nach Neustart im Battle ist das Battle weg | mittel | UI-Test FU02 | immer |
| [BUG-07](#bug-07) | Kein App-Icon | **hoch** (Release) | Screenshot + Asset | immer |
| [BUG-08](#bug-08) | Battle-Screen läuft auf iPhones über den Rand | mittel | Screenshots 17 Pro + 16e | immer |
| [BUG-09](#bug-09) | WebSocket bleibt nach Logout verbunden | mittel | Backend-Log SC02 | immer |
| [BUG-10](#bug-10) | Accessibility: 218 Audit-Befunde | mittel | Accessibility-Audit | immer |
| [BUG-11](#bug-11) | Offline: keine Fehlermeldung, Punkte „0“ | mittel | UI-Test SC07 | immer |
| [BUG-12](#bug-12) | Spieler-Popup nicht durch Tippen daneben schließbar | niedrig | UI-Test SC06 | immer |
| [BUG-13](#bug-13) | Freunde-Seite ohne Standort komplett gesperrt | mittel | Screenshot RT02 + Code | immer ohne Standort |
| [BUG-14](#bug-14) | Challenge-Text im Popup bei großer Schrift abgeschnitten | niedrig | Screenshot | immer (XXXL) |
| [BUG-15](#bug-15) | Interne Spieler-ID statt Name im Popup | niedrig | Screenshot + Code | wenn Gegner außerhalb der Nähe-Liste |
| [BUG-16](#bug-16) | iPad- und Querformat-Layout nicht angepasst | niedrig | Screenshots | immer |
| [BUG-17](#bug-17) | Einstellung „Hintergrundmusik“ ohne Funktion | niedrig | statisch eindeutig | immer |
| [BUG-18](#bug-18) | Rangname falsch geschrieben („Quittttter“) | niedrig | Screenshot + `import.sql` | immer |
| [BUG-19](#bug-19) | Gegner-Avatar immer gleich, Sprachmix „TAP TO VOTE“ | niedrig | Screenshots | immer |
| [BUG-20](#bug-20) | Keine Rückmeldung nach falscher Wissens-Antwort | mittel | UI-Test GP14 | immer |

---

### BUG-01
**API und WebSocket ohne Authentifizierung** · kritisch

- **Voraussetzung:** Backend erreichbar (lokal getestet, Produktion aus Konfiguration abgeleitet)
- **Schritte (lokal):**
  1. `curl http://localhost:8080/api/players`
  2. `curl -X PUT /api/players/demo-2 -d '{"id":"demo-2","name":"GEHACKT","latitude":1,"longitude":1}'`
  3. `curl /api/challenges`, `curl /api/admin/overview`
- **Erwartet:** 401/403 ohne gültiges Token; nur eigene Daten änderbar
- **Tatsächlich:** alles HTTP 200. Alle Spieler mit **genauer Position**, **fremder Spieler umbenannt und versetzt**, richtige Wissens-Antworten, Admin-Daten. Die App sendet ihr Access-Token nie mit (`grep Authorization` → 0 Treffer). Das Backend hat kein `@Authenticated`/`@RolesAllowed`; Admin-Ressourcen inkl. **Ban** sind `@PermitAll`. Der WebSocket identifiziert Spieler nur über `?playerId=`.
- **Belege:** `logs/05_security_rest_unauth.txt`; `KeycloakAuthService.swift:21,119`; `AdminBanResource.java:22`
- **Dateien:** alle Services (`PlayerLocationService`, `FriendsService`, `ShopService`, `ChallengesService`), `GameSocketService.swift:84`, Backend-Ressourcen
- **Lösung:** App: `Authorization: Bearer <token>` bei allen Anfragen; beim WebSocket-Handshake Token als Header oder Query mitgeben. Backend: `quarkus.http.auth.permission` bzw. `@Authenticated` für `/api/*` und `/ws/*`, Player-ID aus dem Token (`sub`) statt aus dem Request, `@RolesAllowed("admin")` für `/api/admin/*`, `GET /api/players` entfernen oder einschränken, Dashboard-Liste mit Antworten nur für Admins. Refresh-Token-Handling in der App.

### BUG-02
**Anfrage eines Dritten kapert das laufende Battle** · hoch

- **Voraussetzung:** Spieler ist in einem angenommenen Battle mit A
- **Schritte:** A fordert heraus → Annehmen → während des Battles fordert B heraus → „AUFGEBEN“
- **Erwartet:** Aufgeben beendet das Battle mit A; B's Anfrage wird abgelehnt oder in eine Warteschlange gestellt
- **Tatsächlich:** Die App sendet `DONE_SURRENDER` für **B's Anfrage** (Battle 15). Battle 14 mit A hängt. Die App bleibt in „Ergebnis wird berechnet“, das über B's Popup liegt.
- **Reproduzierbarkeit:** 1/1 (deterministisch laut Code)
- **Belege:** `screenshots/GP17_after_surrender.jpg`, `logs/06_GP17_backend_evidence.txt`
- **Dateien:** `MapView.swift:1286` (`currentBattleId = battleId` ohne Prüfung), `1277-1296`
- **Lösung:** Während `activeFullScreen != .none` oder `activeBattleInfo != nil` keine neue `currentBattleId` setzen. Eingehende Anfragen automatisch mit `DECLINED` beantworten (Grund „im Battle“) oder serverseitig ablehnen, wenn der Empfänger ein laufendes Battle hat (Regel analog zu „eine offene Anfrage pro Paar“). Battle-IDs pro Rolle getrennt halten (`incomingBattleId`, `activeBattleId`).

### BUG-03
**Wissens-Battle hängt, wenn beide falsch antworten** · hoch

- **Schritte:** Wissens-Battle annehmen → falsche Antwort bestätigen → Gegner antwortet ebenfalls falsch
- **Erwartet:** Unentschieden, erneute Runde oder Zeitlimit mit Ergebnis
- **Tatsächlich:** kein Ergebnis nach 20 s (bis zu 10 min, dann `ABANDONED`); keine erneute Antwort möglich
- **Belege:** `screenshots/GP14_both_wrong_after_20s.jpg`, Beobachtungen `resolvedAfter20s=false`, `canAnswerAgain=false`
- **Dateien:** `KnowledgeBattleView.swift:88-93`; Backend `GameSocket.handleBattleAnswer`
- **Lösung:** Backend: Antworten beider Spieler zählen. Sind beide falsch → Unentschieden (`List.of(NOBODY)`), ebenso bei Zeitlimit (z. B. 30 s). Nur eine Antwort pro Spieler zulassen (verhindert auch Durchprobieren per API). Client: Rückmeldung „falsch“ und Countdown anzeigen.

### BUG-04
**Dark Mode unbrauchbar** · hoch

- **Voraussetzung:** System-Erscheinungsbild „Dunkel“
- **Schritte:** `xcrun simctl ui <udid> appearance dark` → eingehende Challenge, Karte, Ergebnis
- **Erwartet:** Markenfarben bleiben erhalten oder haben passende dunkle Varianten
- **Tatsächlich:** „CHALLENGE!“ Weiß auf Weiß, gelber Textkasten und grüner „ANNEHMEN“-Button werden weiß, Karten-Buttons grau ohne erkennbare Symbole, „ZURÜCK ZUR KARTE“ weiß
- **Belege:** `screenshots/LAY_17Pro-dark-XXXL_2_incoming.jpg`, `…_4_lose.jpg`, `…_1_map.jpg`
- **Ursache:** `Assets.xcassets/Challengr-{Yellow,Green,Black,White}.colorset` und `Chalengr-Red.colorset` haben für `luminosity: dark` jeweils **reines Weiß**
- **Lösung:** Dark-Varianten auf die Markenfarben setzen oder entfernen. Alternativ die App mit `.preferredColorScheme(.light)` / `UIUserInterfaceStyle = Light` fixieren, bis ein dunkles Design existiert.

### BUG-05
**Nach Neustart wird die Annahme der eigenen Anfrage ignoriert** · hoch

- **Schritte:** Spieler herausfordern → App beenden → neu starten → Gegner nimmt die alte Anfrage an
- **Erwartet:** App zeigt nach dem Neustart „Anfrage gesendet“ und wechselt bei Annahme ins Battle
- **Tatsächlich:** Warte-Overlay weg; bei Annahme bleibt die App auf der Karte (der Gegner ist allein im Battle). Ein erneuter Versuch wird vom Server abgelehnt („offene Challenge“), der Spieler sitzt also fest, bis die Anfrage abläuft.
- **Belege:** `screenshots/FU01_*.jpg`
- **Dateien:** `MapView.swift:1319-1372` (`onBattleAccepted` verlangt `currentBattleId == battleId`)
- **Lösung:** Backend-Endpunkt „offene/aktive Battles des Spielers“ (oder Zustellung von `battle-requested` auch an den **Absender** beim Reconnect, analog `deliverPendingRequests`). App stellt `outgoingBattleInfo` bzw. das aktive Battle beim Start wieder her.

### BUG-06
**Nach Neustart im Battle ist das Battle weg** · mittel

- **Schritte:** Battle annehmen → App beenden → neu starten
- **Tatsächlich:** Karte statt Battle. Das Ergebnis kommt aber trotzdem an, wenn der Gegner das Battle beendet (FU02b bestanden).
- **Belege:** `screenshots/FU02_after_relaunch_in_battle.jpg`, `FU02_result_after_relaunch.jpg`
- **Lösung:** wie BUG-05 (aktives Battle beim Start laden). Mindestens einen Hinweis „Du hast ein laufendes Battle“ mit „Aufgeben“ anzeigen.

### BUG-07
**Kein App-Icon** · hoch (Release-Blocker)

- **Beobachtet:** Homescreen und Mitteilung zeigen das Platzhalter-Raster
- **Beleg:** `screenshots/GP19_homescreen_notification.jpg`; `AppIcon.appiconset/Contents.json` hat 3 Einträge ohne `filename`
- **Lösung:** 1024×1024-Icon (hell, dunkel, getönt) hinterlegen. Ohne Icon lehnt App Store Connect den Upload ab.

### BUG-08
**Battle-Screen läuft auf iPhones über den Rand** · mittel

- **Geräte:** iPhone 17 Pro (402 pt), iPhone 16e (390 pt)
- **Tatsächlich:** Spielerkarten und „AUFGEBEN“ rechts abgeschnitten, Titel wird von der oberen Karte überdeckt, der eigene Name klebt am Rand
- **Belege:** `screenshots/GP10_battle_view.jpg`, `LAY_iPhone16e_3_battle.jpg`
- **Ursache:** `BattleView.swift:297-321`. Feste Breiten: Avatar 250 pt + Abstand 12 + Name `minWidth: 110` + Innenabstände ≈ 22 pt → ≈ 394 pt, dazu äußere Paddings
- **Lösung:** Breiten relativ zur `GeometryReader`-Breite berechnen (`compact` für alle iPhones), Name mit `layoutPriority` und ohne `minWidth`; Titel mit fester Höhe oberhalb der Karten.

### BUG-09
**WebSocket bleibt nach Logout verbunden** · mittel

- **Schritte:** Einstellungen → Abmelden (Login-Screen erscheint) → Gegner fordert den abgemeldeten Spieler heraus
- **Erwartet:** keine Zustellung („No active WebSocket session“)
- **Tatsächlich:** `Sending WS payload to player audit-1` – die Session ist noch offen
- **Beleg:** `logs/09_SC02_logout_socket_evidence.txt`
- **Dateien:** `MapView.swift:665-669` (kein `socket.disconnect()`), `GameSocketService.swift:129-138`
- **Lösung:** Im `onDisappear` der `MapView` bzw. in `KeycloakAuthService.clearSession` `socket.disconnect()` aufrufen. Standort-Updates stoppen.

### BUG-10
**Accessibility: 218 Befunde** · mittel

- **Beleg:** `logs/08_accessibility_audit_raw.jsonl`, `screenshots/A11Y_*.jpg`
- **Wesentlich:** VoiceOver-Labels sind SF-Symbol-Namen („gearshape.fill“, „person.fill“, „trophy.fill“); der Profil-Button heißt „playerBoy“ bzw. mit Badge „1“; 55 Kontrastbefunde; kein Dynamic Type (`.system(size:)` überall); 6 zu kleine Touch-Flächen; Karten-Buttons hinter modalen Popups erreichbar
- **Lösung:** `accessibilityLabel` für alle Icon-Buttons und Pins („Einstellungen“, „Shop“, „Profil, 1 neue Anfrage“, „Max, Rang Scrapper“), `.accessibilityHidden` für dekorative Bilder, `.accessibilityAddTraits(.isModal)` für Overlays, `Font.TextStyle` statt fester Größen, Kontraste ≥ 4,5:1.

### BUG-11
**Offline: keine Fehlermeldung, Punkte „0“** · mittel

- **Schritte:** App mit nicht erreichbarem Backend starten
- **Tatsächlich:** Punkte-Chip „0“, „Noch keine Spieler in deiner Nähe“. Kein Hinweis auf die fehlende Verbindung; nur der Shop meldet „nicht erreichbar“.
- **Belege:** `screenshots/SC07_offline_map.jpg`, `SC07_offline_shop.jpg`
- **Dateien:** `MapView.swift:111` (`ownPoints = 0` als Startwert), `1227-1229` (Fehler nur `print`)
- **Lösung:** Punkte optional (`Int?`) und „–“ anzeigen, solange nichts geladen ist; Verbindungs-Banner bei REST- und WebSocket-Fehlern.

### BUG-12
**Spieler-Popup nicht durch Tippen daneben schließbar** · niedrig

- **Beleg:** `screenshots/SC06_popup_after_tap_outside.jpg`
- **Dateien:** `MapView.swift:808-860` (Overlay ohne Hintergrund-Tap)
- **Lösung:** Tippen auf die Karte oder eine Schließen-Schaltfläche setzt `showPlayerPopup = false`.

### BUG-13
**Freunde-Seite ohne Standort komplett gesperrt** · mittel

- **Tatsächlich:** „Standort benötigt für Freunde in der Nähe.“ Die ganze Seite (Freundesliste, Anfragen, QR-Einladung, Geschenke) ist unerreichbar.
- **Beleg:** `screenshots/RT02_friends.jpg`
- **Datei:** `ProfileContainerView.swift:64-75`
- **Lösung:** `FriendsListView` immer anzeigen; nur den Abschnitt „In der Nähe“ vom Standort abhängig machen.

### BUG-14
**Challenge-Text im Popup bei größter Schrift abgeschnitten** · niedrig
„Wer hält länger einen Plank (Unter…“. Beleg: `screenshots/LAY_17Pro-dark-XXXL_2_incoming.jpg`. Ursache nicht abschließend ermittelt (Layout-Kompression im `GameCard` bei geänderter Content-Size). Lösung: `.fixedSize(horizontal: false, vertical: true)` für den Challenge-Text und Dynamic Type einführen.

### BUG-15
**Interne Spieler-ID statt Name** · niedrig
Ist der Gegner nicht in der Nähe-Liste, steht im Popup „GEGNER OPP-LAY-17PRO-DARK-XXXL“, also die rohe ID. Beleg: `screenshots/LAY_17Pro-dark-XXXL_2_incoming.jpg`; `MapView.swift:932, 1012, 1333`. Lösung: Namen per `GET /api/players/{id}` nachladen oder im `battle-requested`-Payload mitschicken.

### BUG-16
**iPad- und Querformat-Layout nicht angepasst** · niedrig
Belege: `screenshots/LAY_iPadPro11_3_battle.jpg`, `LAY_iPhone17Pro_landscape_map.jpg`. Lösung: Querformat auf dem iPhone sperren (Info.plist) und iPad-Layouts mit `horizontalSizeClass` anpassen oder iPad vorerst aus `TARGETED_DEVICE_FAMILY` nehmen.

### BUG-17
**Einstellung „Hintergrundmusik“ ohne Funktion** · niedrig
`SettingsView.swift:8, 23` – `isMusicEnabled` wird nirgends gelesen, es gibt keine Musik. Lösung: entfernen oder Musik umsetzen.

### BUG-18
**Rangname falsch geschrieben** · niedrig
Profil und Trophy Road zeigen „Quitttter“; `import.sql` enthält „Quittttter“, `Documentation/RankingSystem.md` „Quitter“. Beleg: `screenshots/RT02_profile.jpg`, `RT02_trophy_road.jpg`.

### BUG-19
**Gegner-Avatar immer gleich, Sprachmix** · niedrig
Gegner erscheint in Battle und Ergebnis immer als „playerGirl“; die Voting-Kacheln sind englisch beschriftet („TAP TO VOTE“). Belege: `screenshots/GP10_*.jpg`. Lösung: Avatar des Gegners über das Backend übertragen; Texte vereinheitlichen.

### BUG-20
**Keine Rückmeldung nach falscher Wissens-Antwort** · mittel
Nach „Antwort bestätigen“ bleibt der Button grün (gesperrt, aber optisch aktiv), es gibt keinen Hinweis richtig/falsch. Beleg: `screenshots/GP14_both_wrong_after_20s.jpg`; `KnowledgeBattleView.swift:88-110`. Lösung: Button deaktiviert darstellen; Server meldet „falsch“ zurück; Countdown anzeigen.
