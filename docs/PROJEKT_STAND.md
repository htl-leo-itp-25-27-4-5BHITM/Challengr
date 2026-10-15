# Challengr – Projektstand und Übergabe

Stand: **15. Oktober 2026** · Branch `feature/liga-modus` (auf GitHub) · `main` steht noch auf `7e39882`

Diese Datei fasst zusammen, worum es geht, was gebaut wurde, wie alles läuft und was offen ist.
Sie ist zum Weitermachen gedacht – für das Team und für eine neue Claude-Sitzung
(„Lies `docs/PROJEKT_STAND.md` und mach bei *Offene Punkte* weiter“).

---

## 1. Worum es geht

**Challengr** ist ein ortsbasiertes Multiplayer-Spiel fürs iPhone: Spieler sehen andere Spieler in der Nähe
auf einer 3D-Karte und fordern sie heraus.

- **Liga** (um Trophäen) mit zwei Spielarten:
  - **Quiz-Show**: 4 Wissensfragen à 15 s im animierten 3D-Fernsehstudio, Punkte für richtig + Tempo.
  - **Real-Life-Challenge**: der Server lost eine Challenge aus, die das iPhone misst (Sprint, Lautstärke, Kompass, Schütteln, Liegestütze, Kamera, Check-in-Spot).
- **Friendly**: Kategorie und Challenge frei wählbar, es geht um nichts; „Geschafft“/„Aufgeben“, kein Voting mehr.
- Dazu: 10 freischaltbare 3D-Figuren (4 davon nur über Ränge der Trophy Road), Freunde, Geschenke, Shop (zurzeit geschlossen),
  Hotspot an der Schule mit täglichem Check-in, Emotes, animierte Trophy Road, Profil, Tag/Nacht-Zyklus auf der Karte.

**Aktuelles Ziel:** Öffentlicher **TestFlight-Test an der eigenen Schule** (viele Tester, viele minderjährig).
Danach irgendwann App Store – dafür ist ein eigener Server statt der Schul-Cloud geplant.

**Vorgaben vom Team (wichtig für Entscheidungen):**
- Es soll ein **eigenes Projekt** sein, die Schule nicht nennen (Bundle-ID, Texte). Ausnahmen, die bleiben dürfen:
  die Server-URL `it220257.cloud.htl-leonding.ac.at` (bis zum eigenen Server) und der Hotspot „HTL Leonding“ im Spiel.
- Commits sind ausdrücklich erlaubt, sobald ein Teilschritt fertig und getestet ist. **Pushen nur nach Rückfrage.**
- Antworten/Doku auf Deutsch.

---

## 2. Aufbau

| Teil | Ort | Technik |
|---|---|---|
| iOS-App | `Swift/Challengr/` | SwiftUI, MapKit, SceneKit (3D-Figuren), Default Actor Isolation = MainActor |
| Backend | `Backend/challengrbackend/` | Quarkus 3.28 (Java 25), REST + Jakarta-WebSocket `/ws/game`, Hibernate/Panache, PostgreSQL, OIDC (Keycloak) |
| Admin-Dashboard | `Dashboard/` | Angular 21 mit SSR (Node-Server), Keycloak-Login (PKCE), liefert auch `/datenschutz.html` aus |
| WebApp | `WebApp/` | Vite; **für TestFlight abgeschaltet** (`k8s/webapp.yaml` → `replicas: 0`), schickt noch keinen Login |
| Deployment | `k8s/`, `scripts/` | Leo Cloud (Kubernetes, Namespace `student-it220257`), Images auf ghcr.io |

**Server:** `https://it220257.cloud.htl-leonding.ac.at` – Ingress: `/auth` → Keycloak, `/api` + `/ws` → Backend, `/` → Dashboard.

**Auth:** Keycloak-Realm `challengr`. Spieler-ID = Token-Claim `sub`. Clients: `challengr-ios` (App, PKCE),
`challengr-dashboard` (Dashboard, PKCE), `challengr-backend` (Token-Prüfung), `challengr-admin-api`
(Service-Account mit `manage-users`/`view-users` für Sperren und Konto-Löschen). Realm-Rolle `admin` = Dashboard-Zugriff
(aktuell Benutzer `test`; besser: eigene Konten mit Rolle `admin`).

---

## 3. Was gebaut wurde (chronologisch, mit Commits)

### Spiel-Features
| Commit | Inhalt |
|---|---|
| `4baaa54` | Emotes (Server-Whitelist + Drosselung), Hotspot an der Schule (48.26832, 14.25138, 60 m; +10 Punkte, Erster des Tages +15), Karten-Menü, Figuren am Server |
| `c8ee79b` | Start-Figuren Junge/Mädchen, Kompass neu, Pokémon-GO-artiges Münz-Menü, Profil/Freunde im dunklen Spiel-Look |
| `edddb1e` | Liga-Modus + Friendly ohne Voting, Quiz-Show (4 Fragen, 15 s, 100 + bis 50 Tempo-Bonus, Gleichstand = Unentschieden), Trophäen, 30 neue Wissensfragen |
| `1da0e42` | **Eine** Liga: Quiz-Show und Real-Life zählen auf denselben Trophäen-Stand (`Player.trophies`) |
| `96df336` | Quiz-Show als **3D-Fernsehstudio** (`QuizStageView`): beide Spieler hinter Pulten, Merlo als Quizmaster, Kamerafahrten, Reaktionen; nur ein SceneKit-Fenster, keine eigenen Shader, 2D-Fallback bei Magenta |
| `360e1da` | Kartenfilter entfernt (zeigte nur „test“/„cookieclicker“) – TestFlight-Tester sahen sich sonst nicht |
| `783988a` | **Viele Spieler auf einem Fleck:** nearby nur Kartenausschnitt aus der DB, max. 30 nächste + Gesamtzahl im Header `X-Nearby-Total`; Positions-Events max. alle 5 s pro Spieler; App spart Animationen (getestet mit 200 Spielern: 21 ms) |
| `04278ed`, `8bc1912` | **Trophy Road neu:** durchgehender Weg im Spiel-Look, Figur läuft vom zuletzt gesehenen Stand zum aktuellen, Rang-Aufstieg mit Konfetti, Regeln hinter „i“. **Trophäen nach Trophäen-Abstand** (`TrophyMath`: +30/−20, ±1 pro 25 Abstand, Sieg 10–50, Verlust max. 40). **Rang-Figuren:** Käpt'n Rex (Contender), Hayato (Tryhard), Kai (Brawler), Kage (Dueler) nach höchstem je erreichtem Stand (`Player.highestTrophies`); bereits gewählte Figur bleibt. Höchster Rang nach oben offen |
| `887668e`, `930713b`, `19237c7` | **Feinschliff Testphase:** Karte drehbar und zoombar (200 m–2,5 km), aber nicht verschiebbar oder kippbar – nach jeder Geste springt sie zurück auf den Spieler; Tipp-Welle als Rückmeldung; Shop geschlossen (`ShopView.isOpen = false`); Foto-Challenge abgeschaltet (`ChallengeRepository.DISABLED_PREFIXES`); Trophäen/Punkte nie unter 0; **Punkte in der App ausgeblendet** – überall nur Trophäen (Karten-Chip → Trophy Road, Profil, Freunde, Trophäenverlauf statt Punkteverlauf) |
| `573fbab`, `be10828` | **235 Wissensfragen:** Fragenkatalog `Backend/…/resources/quiz-questions.txt` (eine Zeile pro Frage: `Frage \| richtig \| falsch \| falsch \| falsch`), `QuizQuestionSync` legt beim Start fehlende Fragen an – neue Fragen = Zeile anhängen + `deploy-cloud.sh backend`. `QuizHistory` bevorzugt Fragen, die beide Spieler zuletzt nicht hatten (letzte 100 pro Spieler, nur im Speicher). Herausfordern aus dem Freundes-Menü schließt das Menü |
| `90d7ecd`, `56e5eb6`, `29505ab` | **Namen ändern** (`PUT /api/players/{id}/name`, 3–20 Zeichen, Filter, eindeutig); Login/Standort überschreiben den Namen nicht mehr. **Freundesprofil** im Spiel-Look. **Tag/Nacht** (`SkyCycle`, `SkyOverlay`): Karte nach echtem Sonnenstand hell/dunkel, Dämmerung, Sterne – nur Optik |

| `62916fe` | **Angemeldet bleiben:** Refresh-Token (Scope `offline_access`) im iOS-Schlüsselbund (`TokenStore`), beim Start stille Anmeldung ohne Browser; ~30 Tage ohne Nutzung gültig (Keycloak „Offline Session Idle“), jede Nutzung verlängert |

**Trophäen-Regel (`control/TrophyMath`):** Sieg +30 / Niederlage −20 bei gleich vielen Trophäen; pro 25 Trophäen, die der Verlierer
mehr hat, +1 für beide Seiten (Außenseiter-Sieg bringt mehr, Favorit verliert mehr). Sieg 10–50, Verlust 5–40, nie unter 0.
Unentschieden/Friendly: nichts. Ränge (`reference-data.sql`): Quitter 0, Punchbag 100, Scrapper 200 (Start), Contender 350,
Tryhard 600, Brawler 950, Dueler 1400, Challengr 2000+ (nach oben offen).

**Punkte vs. Trophäen:** Trophäen = Liga-Rang – das Einzige, was die App zurzeit zeigt. Punkte (Währung für den späteren Shop) sammelt der Server weiter im Hintergrund (Liga-Sieg = Trophäen-Gewinn, Hotspot-Check-in), angezeigt werden sie erst wieder, wenn der Shop öffnet.

### TestFlight-Sicherheits-Checkliste (`docs/audit/TESTFLIGHT_SECURITY_CHECKLIST.md`)
| Punkt | Commit | Umsetzung |
|---|---|---|
| A1 Datenbank bleibt | `177e4dd` | `%prod`: `schema-management=update`; Stammdaten in `reference-data.sql`, `ReferenceDataSeeder` legt sie nur an, wenn sie fehlen |
| A2 Login-Pflicht | `53a775f`, `aa753fb` | alle persönlichen Endpoints `@Authenticated`, fremde IDs → 403 (`security/CurrentPlayer`); App: `Services/AuthSession.swift` (`API.data`) hängt Bearer-Token an, erneuert es, bei 401 zurück zum Login |
| A3 Admin nur für Admins | `53a775f`, `6726bd6` | `@RolesAllowed("admin")`; Dashboard mit Keycloak-Login |
| A4 WebSocket mit Login | `53a775f` | Login beim Upgrade, `?playerId=` wird ignoriert; Logs nur mit Nachrichtentyp |
| A5 Standortschutz | `53a775f` | nearby: eigene gespeicherte Position, max. 300 m, nur aktive/sichtbare, Koordinaten auf ~50 m gerundet; fremde Profile ohne Koordinaten; „Unsichtbar“ |
| A6 Secrets | `177e4dd`, `3399ed1` | keine Fallback-Passwörter in Prod; `ProdSecretsGuard` verweigert den Start mit Standardwerten; `scripts/rotate-secrets.sh` |
| A7 iOS | `1735fad` | Berechtigungstexte, `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption = NO`, nur iPhone |
| B1 Konto löschen | `db3d4da` | `DELETE /api/players/me` + Keycloak-Konto; Battles anonymisiert („Gelöschter Spieler“) |
| B2 Melden/Blockieren | `b8d7f25` | `/api/safety/…`, Server setzt Blockierung überall durch, Namensfilter, Dashboard-Seite „Meldungen“ |
| B3 Datenschutz | `76b8085`, `918ffc8`, `892b3a0` | `/datenschutz.html` (Dashboard/public), Onboarding-Schritt mit Altersbestätigung ab 14 |
| B4 Speicherdauer | `db3d4da` | Konten nach 365 Tagen Inaktivität gelöscht |
| B5 Prüfer-Zugang | – | Konto `applereview` existiert; Bot/Übungsmodus fehlt (erst für den App Store nötig) |

### TestFlight-Upload
| Commit | Inhalt |
|---|---|
| `1a98552`, `892b3a0` | Release-Bundle-ID **`com.challengrapp.challengr`** (Debug bleibt `at.htl.leonding.challengr.binder`), `scripts/upload-testflight.sh` |

---

## 4. Aktueller Stand (live)

**Leo Cloud** – Backend läuft seit 14.10. (16:34) mit dem Stand `29505ab` (Dashboard `783988a`), 235 Wissensfragen:
- Backend, Dashboard, Keycloak, Postgres laufen; WebApp aus.
- Postgres- und Keycloak-Admin-Passwort am 12.10. neu gesetzt (`rotate-secrets.sh`).
- Keycloak 24 (läuft mit `start-dev`, Daten in Postgres): Selbst-Registrierung **an**, „Verify email“ **aus** (kein Mailserver eingetragen).
  Admin mit 2FA (Authenticator-App). Benutzer `test` (Admin-Rolle): am 15.10. sollte 2FA entfernt und ein neues Passwort gesetzt werden –
  falls erledigt, liegt es im Schlüsselbund „Challengr Dashboard test“.
- Spieler (Stand 14.10.): 8 Konten. `bin_der_dominik` wurde zum Testen per Hand auf 1342 Trophäen gesetzt → daraufhin
  **offene Meldung** von `mskes07` („zu viele Trophäen“) im Dashboard – einfach „Erledigt“, nicht sperren.
- Backups vom 12.10. und 14.10. (vor jedem Deploy) in `~/Developer/ChallengrProjekt/Backups/` (lokal, nicht im Repo).

**Apple:**
- Apple Developer Program (Individual, Sebastian Lehner), **Team-ID `9CK2N38H9M`**, Verlängerung 13.10.2027 (Auto-Renew an).
- App Store Connect: App „Challengr“, SKU `challengr-ios`.
- TestFlight-Gruppen: intern **„Team“**, extern **„Schule“** (2 Tester). Testinformationen inkl. `applereview`-Login ausgefüllt.
- Builds: `2610121422` (Im Test, alt – Kartenfilter-Bug), `2610130934` (Kartenfix), **`2610131028`** (Kartenfix + viele Spieler), `2610141130` (Trophy Road neu, Rang-Figuren, Karte nur drehbar, Shop zu, nur Trophäen), **`2610141213`** (+ Karte zoombar mit Spieler in der Mitte, Freundes-Menü schließt nach Herausfordern, angemeldet bleiben über Offline-Token im Schlüsselbund), **`2610141631`** (+ Freundesprofil im Spiel-Look, Namen ändern in den Einstellungen, Tag/Nacht-Zyklus auf der Karte) – **`2610141631` der Gruppe „Schule“ zuweisen**, falls noch nicht geschehen. Text für „Was soll getestet werden?“: `docs/TESTFLIGHT_TESTER_TEXT.md`.

**Git:** `feature/liga-modus` ist auf GitHub aktuell. `main` hängt hinterher (Stand `7e39882`, 13.10.) – bei Bedarf mergen.

**Wo die Passwörter liegen** (nie im Repo):
| Schlüsselbund-Eintrag (macOS) | Wofür |
|---|---|
| Challengr Leo Cloud Postgres | Datenbank |
| Challengr Leo Cloud Keycloak-Admin | Keycloak-Admin-Konsole (`…/auth/admin`, Benutzer `admin`) |
| Challengr Apple-Prüfer-Account | App-Login `applereview` |
| Challengr Dashboard test | Dashboard-Login `test` (nur, wenn am 15.10. so gespeichert) |

Anzeigen: `security find-generic-password -s "<Eintrag>" -w`. Postgres/Keycloak-Admin stehen zusätzlich im
Kubernetes-Secret `challengr-secrets`. Verloren? `./scripts/rotate-secrets.sh` setzt neue.

---

## 5. Offene Punkte (in dieser Reihenfolge)

**Der öffentliche TestFlight-Test läuft:** Neuester Build ist der externen Gruppe „Schule“ zugewiesen, der
öffentliche Link ist aktiv, Schüler spielen bereits.

Erledigt am 13.10.: hängende Keycloak-Konten freigeschaltet, Passwort von `test` geändert, 2FA für den
Keycloak-Admin eingerichtet, Kontakt-Mail bestätigt (`challengrapp.official@gmail.com`), alles gepusht,
Zustimmung der Schule liegt vor, Test mit zwei iPhones durchgeführt (Checkliste Teil C/D).

0. **Kurzfristig:** Build `2610141631` der Gruppe „Schule“ zuweisen; Meldung zu `bin_der_dominik` im Dashboard auf „Erledigt“;
   Dashboard-Zugang klären (2FA bei `test` löschen oder eigenes Konto mit Rolle `admin`); **Instagram-Konto `challengr.game`
   prüfen** – im Gmail-Postfach lagen am 14.10. Mails „New login … Samsung SM-A556B/SM-A566B“ und „password has been changed“.
   Falls das nicht das Team war: Konto sichern, Passwort ändern, 2FA an.
1. **Tägliches DB-Backup – dringend**, weil jetzt echte Spielerdaten anfallen (kein CronJob im Namespace).
   Z. B. Kubernetes-CronJob mit `pg_dump`, 7 Tage aufbewahren. Bis dahin regelmäßig manuell sichern (siehe Befehle).
2. **Mailserver in Keycloak** (Realm **challengr** → Realm settings → Email; z. B. Gmail mit App-Passwort,
   `smtp.gmail.com:587`, StartTLS; *Save*, dann *Test connection*). Danach „Verify email“ wieder an.
   Ohne Mailserver geht „Passwort vergessen“ nicht – solche Fälle im Keycloak-Admin manuell zurücksetzen.
   Keycloak 24 kann keine Login-Codes per Mail – wer „einen Code“ verlangt bekommt, hat 2FA (Authenticator) am Konto.
   Danach möglich: Mail ans Team bei neuer Meldung (Backend bräuchte dasselbe Gmail-App-Passwort als Secret).
3. **Laufender Betrieb:** Meldungen im Dashboard („Meldungen“) regelmäßig ansehen; TestFlight-Feedback/Crashs in
   App Store Connect prüfen; Build läuft nach 90 Tagen ab → vorher neu hochladen und der Gruppe „Schule“ zuweisen.
4. **Keycloak auf `start` statt `start-dev` umstellen** (`k8s/` Keycloak-Deployment; braucht Hostname-/Proxy-Einstellungen, vorher Backup).
5. **Nächste Spielideen** (Vorschlag, Reihenfolge): Ranglisten (Schule/Freunde) → Übungsmodus gegen Bot (zugleich B5) →
   tägliche Aufgaben + Shop-Items mit Wirkung (50:50-Joker, Revanche-Ticket, Trophäen-Schild, Tarnumhang), dann Shop öffnen →
   Push-Benachrichtigungen bei Herausforderungen → Hotspot-König, mehr Hotspots, Saisons, Fragen melden in der Quiz-Show,
   Dashboard: Trophäen setzen, Fragen verwalten. Grundsatz: Tageszeit/Nacht nie mit Spielvorteilen verknüpfen (Minderjährige).
6. Später (App Store): B5 Prüfer-Zugang ohne zweiten Spieler (Bot/Übungsmodus), eigener Server + Domain,
   EU-Händlerstatus in App Store Connect, WebApp mit Login.

**Ablauf:** TestFlight-Builds laufen nach 90 Tagen ab → vorher neu hochladen.

---

## 6. Wichtige Befehle

```bash
cd ~/Developer/ChallengrProjekt/Challengr

./scripts/test-all.sh backend                   # Backend-Tests (Quarkus, H2)
./scripts/deploy-cloud.sh backend|dashboard     # bauen (inkl. Tests), Image pushen, auf der Leo Cloud neu starten
                                                # (braucht Docker Desktop und kubectl-Kontext "leocloud")
./scripts/upload-testflight.sh 9CK2N38H9M       # App archivieren + zu TestFlight hochladen (Build-Nr. automatisch)
./scripts/rotate-secrets.sh                     # neue Passwörter Postgres/Keycloak-Admin/applereview

kubectl -n student-it220257 get pods            # Status
kubectl -n student-it220257 logs deploy/challengr-backend --tail=100
kubectl -n student-it220257 exec deploy/challengr-postgres -- pg_dump -U postgres postgres > backup.sql

# Spieler per Hand ändern (Claude darf nicht in die Live-DB schreiben → selbst ausführen). Spalten ohne Unterstrich!
kubectl -n student-it220257 exec deploy/challengr-postgres -- psql -U postgres -c \
  "update player set trophies=1342, highesttrophies=greatest(highesttrophies,1342) where name='…';"
```

**Neue Quizfragen:** Zeile in `Backend/challengrbackend/src/main/resources/quiz-questions.txt` anhängen
(`Frage | richtig | falsch | falsch | falsch`), dann `deploy-cloud.sh backend`. Bestehende Fragen nicht umformulieren (sonst doppelt).
**Dashboard-Meldungen:** `https://it220257.cloud.htl-leonding.ac.at/reports` (Login mit Admin-Rolle).

App-Unit-Tests: `xcodebuild -project Swift/Challengr/Challengr.xcodeproj -scheme Challengr -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ChallengrTests`

**Update-Regel:** Nur-Server-Änderungen (Backend/Dashboard, neue Fragen) → `deploy-cloud.sh`, sofort live, keine Apple-Prüfung.
App-Änderungen → `upload-testflight.sh`; intern sofort verfügbar, extern Build der Gruppe „Schule“ zuweisen
(gleiche Version 1.0 → meist ohne volle Prüfung).

---

## 7. Stolperfallen

- **„Swift Kopie“ gibt es nicht mehr** (gelöscht am 13.10., in der Git-Historie bis `8ea2877`). Zum Testen mit
  zwei Geräten: TestFlight oder zwei Simulatoren mit verschiedenen Konten.
- **Nicht committen:** `…/xcuserdata/…/UserInterfaceState.xcuserstate`.
- **Prod-Wächter:** Das Backend startet in Prod absichtlich nicht mit Standard-Passwörtern oder mit
  `challengr.auth.trust-player-header=true`. Fehlt ein Secret → Pod in CrashLoop (so war es 10.–12.10.).
- **Dev/Test ohne Keycloak:** Im Test-Profil gilt der Header `X-Player-Id` (+ `X-Player-Roles: admin`) als Login;
  die App schickt ihn in Debug-Builds, wenn `AUDIT_PLAYER_ID` gesetzt ist. In Prod wirkungslos.
- **SwiftUI/Swift 6:** `ObservableObject`-Klassen, die in Tests freigegeben werden, als `nonisolated final class`
  deklarieren (sonst malloc-Absturz im Back-Deploy-Shim) – siehe `AvatarCustomizationStore`, `QuizShowModel`, `QuizStudio`, `AuthSession`.
- **3D:** keine eigenen SceneKit-Shader (Magenta auf echten Geräten); nur ein 3D-Fenster gleichzeitig (`CharacterRenderGate`).
- **Projektordner nicht in iCloud:** Er lag früher auf dem iCloud-Desktop; bei vollem Speicher hat macOS Dateien
  ausgelagert und `.git/index` verloren. Jetzt unter `~/Developer/ChallengrProjekt`. Speicher frei halten.
- **Name des Spielers:** nur über `PUT /api/players/{id}/name` änderbar. Die App schickt bei Standort-Updates und beim Login
  den Keycloak-Benutzernamen mit – der Server ignoriert ihn dort absichtlich (sonst würde jede Umbenennung überschrieben).
- **Postgres-Spaltennamen** in Prod ohne Unterstrich (`highesttrophies`, `winnerpointsdelta`, `reporterid` …).
- **Karte:** `interactionModes [.rotate, .zoom]` + Zurückspringen auf den Spieler (`recenter`). `MapCameraBounds` nicht mit
  gleichem Min/Max setzen – dann landet der Spieler am Bildschirmrand.
- **Tag/Nacht testen:** Debug-Builds nehmen `AUDIT_FAKE_TIME` (ISO 8601) als Uhrzeit (`SkyCycle.now()`).
- **UI-Tests im TestHarness:** Sheets aus dem Münz-Menü (Trophy Road, Shop, Einstellungen) öffnen sich in XCUITests oft nicht –
  die Trophy Road lässt sich in der Harness-Kopie über `AUDIT_TROPHY_ROAD=<playerId>` direkt starten. NavigationLinks per Koordinate antippen.
  Das Harness-Backend wird von `sync_backend.sh` überschrieben (eigene Test-Patches dann neu einspielen).
- **Dashboard-Screenshot lokal:** `ng serve` mit einer Proxy-Datei auf `localhost:8080` (+ Header `X-Player-Id`/`X-Player-Roles: admin`)
  und vorher ein Fake-Token in `sessionStorage['challengr.dashboard.auth']` legen; neue Dateien in `public/` sieht `ng serve` erst nach Neustart.
- **Claude-Sicherheitsgrenzen:** Passwörter in Webformulare eintippen, Secrets/Schlüsselbund schreiben und
  Keycloak-Konto-Einstellungen ändern und **Schreiben in die Live-Datenbank** blockiert das Sicherheitssystem → dafür Befehle/Skripte
  vorbereiten, die der Nutzer selbst ausführt. Lesen (psql select, kubectl logs) geht.

**Lokales Test-Setup (nicht im Repo):** `~/Developer/ChallengrProjekt/TestHarness/` – Kopie der App mit UI-Test-Target,
lokales Backend (Test-Profil, Port 8080), scriptbarer Gegner `opponent.mjs` (Port 9099), UI-Tests
(`GameplayTests`, `LeagueTests`, `SafetyTests`, `DemoTests` für Zwei-Simulator-Demos). Ablauf in `TestHarness/README.md`.
Demo-Videos: `~/Developer/ChallengrProjekt/Challengr_Demo_1_Liga_und_Friendly.mp4`, `…_Demo_2_Privatsphaere.mp4`.

---

## 8. Die wichtigsten Aufträge (sinngemäß, in Reihenfolge)

1. „Wir ändern das Challenge-System: Liga um Trophäen und Friendly, wo es um nichts geht. Bei Liga zwei Modi – Wissensfragen und Real-Life-Challenges; das Voting soll weg; bei Wissen eine animierte Quiz-Show mit 4 Fragen.“
   → Entscheidungen: nicht messbare Challenges nur noch im Friendly; Tempo-Bonus bei der Quiz-Show.
2. „Zwei Simulatoren starten und den Ablauf zeigen – du spielst mit zwei Handys gegeneinander.“ → Demo-Videos.
3. „Doch nur **eine** Liga, aber man wählt zwischen Wissensquiz und Real-Life. Die Quiz-Show soll richtig Richtung TV-Show gehen, mit 3D-Animationen, Figuren, die interagieren.“
4. „Im Ordner liegt eine TestFlight-Security-Checkliste – das muss abgehakt werden, damit wir die App veröffentlichen können.“
   → Entscheidung: Dashboard mit Login, WebApp vorerst aus.
5. Schritt-für-Schritt-Anleitung bis TestFlight; Projekt aus iCloud holen; Passwörter tauschen; deployen; Apple-Account kaufen; hochladen.
6. „Eigenes Projekt, nicht die Schule erwähnen“ → Bundle-ID `com.challengrapp.challengr`, Datenschutzerklärung ohne Schule.
7. „Tester bekommen keine Mail“ → Keycloak ohne Mailserver; „Tester sehen sich nicht“ → Demo-Kartenfilter entfernt.
8. „Was, wenn an der Schule 100–200 Leute auf einem Punkt sind?“ → nearby begrenzt, Events gedrosselt, Karte sparsamer.
9. (14.10.) „Trophy Road logischer und mit Animationen; manche Figuren nur über Ränge“ → TrophyMath, neue Trophy Road, Rang-Figuren.
10. „Zoom weg, nicht wegbewegen, nicht 2D; Tipp-Indikator; Shop aus; Foto-Challenge aus; keine Minus-Trophäen; Punkte verwirren“
    → später: „Zoom wieder rein, aber Spieler immer in der Mitte“. Entscheidung: Punkte in der App ausblenden, nur Trophäen.
11. „Freundes-Menü nach Herausfordern schließen“, „200 Wissensfragen – beste Möglichkeit für Abwechslung?“ → Fragenkatalog + Sync + QuizHistory.
12. „Nach App-Beenden neu anmelden ist nervig“ → Offline-Token im Schlüsselbund.
13. „Freundesprofil hässlich, Namen ändern, mskes07 hat komische Trophäen“ → Profil neu, Rename-Endpunkt; Trophäen nachgerechnet: korrekt.
14. „Day-Night-Zyklus, aber rein dekorativ – keine Punkteunterschiede.“
15. Organisatorisch: Mail an den Professor mit dem Plakat (TestFlight-QR-Code) – Vorlage im Chat formuliert.

Weitere Doku: `docs/audit/TESTFLIGHT_ANLEITUNG.md` (Handgriffe bis zum öffentlichen Link),
`docs/audit/TESTFLIGHT_SECURITY_CHECKLIST.md` (Checkliste mit Umsetzungsstand), übrige Audit-Berichte in `docs/audit/`.
