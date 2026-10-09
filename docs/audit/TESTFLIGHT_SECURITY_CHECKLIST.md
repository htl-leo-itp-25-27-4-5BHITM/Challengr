# Sicherheits- und Datenschutz-Checkliste vor dem Schul-Test (TestFlight)

Stand: 9. Oktober 2026 · Branch: `feature/liga-modus`

Ziel: Challengr soll über **TestFlight** an Schüler der eigenen Schule verteilt werden (öffentlicher Einladungslink, bis zu einigen hundert Testern, viele davon minderjährig). Vorher müssen die unten genannten Sicherheits- und Datenschutzpunkte **umgesetzt, getestet und abgehakt** sein.

Der Server bleibt für die Testphase auf der Leo Cloud (`https://it220257.cloud.htl-leonding.ac.at`, Deployment über `k8s/`). Der Umzug auf einen eigenen Server ist **nicht** Teil dieser Liste.

## Aufbau

- **Teil A – Muss vor TestFlight:** ohne diese Punkte keine Einladung an Schüler.
- **Teil B – Muss vor dem öffentlichen App Store:** kann parallel zur Testphase passieren. A1/A2 und B1 lieber gleich mitmachen, weil Apple sie bei der Beta-Prüfung manchmal schon verlangt.
- **Teil C – Organisatorisch:** kein Code, aber Voraussetzung für den Schultest.
- **Teil D – Abnahmetest:** manueller Durchlauf, bevor der TestFlight-Link verteilt wird.

Jeder Punkt hat eine **Abnahme**. Abhaken erst, wenn die Abnahme tatsächlich durchgeführt wurde und bestanden ist.

---

## Wichtig vor dem Start: Was mitbricht

Sobald das Backend Logins erzwingt (A2–A4), hören alle Clients auf zu funktionieren, die noch keinen Token mitschicken:

| Client | Ort | Ruft das Backend auf über |
|---|---|---|
| iOS-App | `Swift/Challengr/Challengr/` | 9 Dateien mit `URLSession`/`URLRequest`, WebSocket in `WebSocket/GameSocketService.swift` |
| WebApp | `WebApp/` (Vite) | `map.js`, `GameSocketClient.js` |
| Admin-Dashboard | `Dashboard/` (Angular) | `src/app/core/api/admin-dashboard-api.ts`, `features/users`, `features/challenges` |

Deshalb gilt:

- Alle drei Clients **im selben Schritt** umbauen oder WebApp und Dashboard bewusst vorübergehend abschalten. Die Entscheidung im PR dokumentieren.
- Backend-Tests laufen mit `%test.quarkus.oidc.enabled=false`. Gesicherte Endpoints brauchen in den Tests `@TestSecurity(user = ..., roles = ...)` (Dependency `quarkus-test-security`), sonst schlagen sie fehl oder testen nichts.
- iOS-Login: Keycloak-Client `challengr-ios`, Authorization-Code-Flow über `ASWebAuthenticationSession`, Token liegt in `KeycloakAuthService.accessToken`. Das ist bereits korrekt und soll so bleiben.
- Nach jeder Änderung `./mvnw test` im Backend ausführen und die App in Xcode bauen.

---

## Einrichtung auf Keycloak und Leo Cloud (vor dem Deployment)

Diese Schritte kann nur jemand mit Zugang zu Keycloak und zum Cluster erledigen:

1. **Realm-Rolle `admin`** im Realm `challengr` anlegen und nur dem Team zuweisen.
2. **Client `challengr-dashboard`** anlegen: Public Client, Standard Flow, PKCE `S256`,
   Redirect-URIs `https://it220257.cloud.htl-leonding.ac.at/*` und `http://localhost:4200/*`,
   Web Origins `https://it220257.cloud.htl-leonding.ac.at` und `http://localhost:4200`.
3. **Client `challengr-ios`**: prüfen, dass Refresh-Tokens ausgestellt werden (Standard).
4. **Client `challengr-admin-api`** (Service Account): Rolle `realm-management/manage-users`,
   damit Sperren und Konto-Löschen funktionieren.
5. **Secrets** in `challengr-secrets`: starke, eigene Werte für `POSTGRES_PASSWORD`,
   `KEYCLOAK_ADMIN_PASSWORD`, `KEYCLOAK_CLIENT_SECRET`, `KEYCLOAK_ADMIN_CLIENT_SECRET`.
   Ohne gültiges `KEYCLOAK_CLIENT_SECRET` und DB-Passwort startet das Backend absichtlich nicht.
6. **Reihenfolge:** Backend und Dashboard zusammen deployen, danach die neue App über TestFlight
   verteilen. Alte App-Versionen funktionieren mit dem neuen Backend nicht mehr (kein Token).
7. **WebApp** bleibt abgeschaltet (`k8s/webapp.yaml`, `replicas: 0`), bis sie ein Token mitschickt.

---

## Teil A – Muss vor TestFlight

### A1 · Datenbank darf beim Neustart nicht gelöscht werden — [ ]

> **Umsetzungsstand (177e4dd):** Code fertig. `%prod` nutzt `update` ohne Load-Script; Stammdaten liegen in `reference-data.sql` und werden vom `ReferenceDataSeeder` nur angelegt, wenn sie fehlen (`ReferenceDataSeederTest`). **Offen:** Abnahme auf der Leo Cloud (`kubectl rollout restart`).

**Problem:** In `Backend/challengrbackend/src/main/resources/application.properties` stehen `quarkus.hibernate-orm.schema-management.strategy=drop-and-create` und `sql-load-script=import.sql` ohne Profil-Präfix. `application-prod.properties` überschreibt das nicht. Jeder Pod-Neustart oder jedes Deployment löscht alle Spieler, Trophäen und Freundschaften.

**Umsetzung:**
- Für `%prod` umstellen: `strategy=update` und `sql-load-script=no-file`. Für `%dev` und `%test` bleibt `drop-and-create`.
- Stammdaten aus `import.sql` (Challenges, Kategorien, Ränge, Shop-Items, Hotspots) dürfen in Prod nicht verloren gehen. Entweder einmalig einspielen oder beim Start idempotent anlegen, wenn sie fehlen.
- Optional, aber empfohlen: Flyway statt `update`.

**Abnahme:**
- Auf der Leo Cloud einen Testspieler anlegen und Punkte sammeln.
- `kubectl rollout restart` für das Backend ausführen.
- Spieler, Punkte und Stammdaten sind danach noch da.

### A2 · Alle REST-Endpoints verlangen einen gültigen Login — [ ]

> **Umsetzungsstand (53a775f, aa753fb):** Code fertig. Alle persönlichen Endpoints `@Authenticated`, Spieler-ID aus dem Token (`sub`), fremde IDs → 403 (`CurrentPlayer`). App schickt `Authorization: Bearer` über `AuthSession`/`API`, erneuert Tokens und fällt bei 401 zum Login zurück. Bewusst öffentlich: Kategorien, Challenges ohne Lösung, Ränge, Shop-Katalog, `/datenschutz.html`. Tests: `SecurityChecklistTest` (ohne Token 401, fremde ID 403, fremder Kauf 403 ohne Münzverlust, eigene ID 200). **Offen:** Abnahme mit `curl` gegen die Leo Cloud.

**Problem:** Kein Endpoint hat `@Authenticated` oder `@RolesAllowed`, und die App schickt keinen `Authorization`-Header. Wer ein Spieler ist, ergibt sich nur aus `playerId` in Pfad oder Query bzw. aus dem Header `X-Player-Id` (`BanEnforcementFilter.java`). Jeder kann fremde Profile ändern (`PUT /api/players/{id}`, `/profile`, `/character`), für fremde IDs im Shop kaufen (`/api/shop/players/{playerId}/purchase`) und fremde Geschenke einlösen (`/api/friends/gifts/{id}/claim?playerId=`).

**Umsetzung:**
- iOS: an jeden Request `Authorization: Bearer <accessToken>` anhängen, am besten über eine zentrale Hilfsfunktion statt in jeder der 9 Dateien einzeln. Abgelaufene Tokens mit dem Refresh-Token erneuern; bei 401 zurück zum Login.
- Backend: alle Klassen unter `boundary/` mit `@Path("/api/...")` mit `@Authenticated` markieren. Ausnahmen nur bewusst und begründet, z. B. öffentliche Stammdaten (Kategorien, Challenges, Ränge, Shop-Katalog).
- Die eigene Spieler-ID **immer aus dem Token** nehmen (`JsonWebToken` bzw. `SecurityIdentity`, Claim `sub` oder das bestehende Mapping Keycloak-User → Player). Pfad- oder Body-IDs für **schreibende** Aktionen nur akzeptieren, wenn sie dem eingeloggten Spieler gehören; sonst `403`.
- `BanEnforcementFilter` auf die ID aus dem Token umstellen, nicht mehr `X-Player-Id`.
- Lesende Endpoints auf fremde Spieler (Profil, Stats) geben nur öffentliche Felder zurück, **keine Koordinaten** (siehe A5).

**Abnahme:**
- `curl` ohne Token auf `PUT /api/players/<id>` liefert `401`.
- Mit Token von Spieler A auf die ID von Spieler B liefert `403`.
- Ein Kauf im Shop mit fremder `playerId` liefert `403`, und der Münzstand von B ändert sich nicht.
- Für A2 gibt es mindestens je einen Backend-Test für „ohne Token“, „fremde ID“ und „eigene ID“.

### A3 · Admin-Endpoints nur für Admins — [ ]

> **Umsetzungsstand (53a775f, 6726bd6):** Code fertig. Ban, Overview, ERD, Meldungen, Challenge-Verwaltung und Spielerliste nur mit Realm-Rolle `admin`. Dashboard meldet sich über den Keycloak-Client `challengr-dashboard` (PKCE) an. Tests: `AdminOverviewResourceTest`, `SecurityChecklistTest`, `ChallengeResourceTest` (401/403/200). ERD bleibt (vom Dashboard genutzt), aber nur für Admins. **Offen:** Keycloak einrichten (siehe „Einrichtung“ unten) und Abnahme.

**Problem:** `AdminBanResource`, `AdminOverviewResource` und `AdminErdResource` sind `@PermitAll` (mit TODO im Code). Jeder kann Spieler sperren und entsperren und Datenbanktabellen lesen (`/api/admin/erd/table/{table}`).

**Umsetzung:**
- Im Keycloak-Realm `challengr` eine Realm-Rolle `admin` anlegen. Nur dem Team zuweisen.
- Die drei Klassen auf `@RolesAllowed("admin")` umstellen. Prüfen, dass Quarkus die Keycloak-Realm-Rollen aus dem Token liest (`quarkus.oidc.roles.role-claim-path` falls nötig).
- Dashboard: Login über Keycloak (eigener Public-Client, PKCE) und Bearer-Token an alle Admin-Calls.
- Prüfen, ob `AdminErdResource` in Prod überhaupt gebraucht wird. Wenn nicht: nur im Dev-Profil aktivieren.

**Abnahme:**
- Ohne Token `401`, mit normalem Spieler-Token `403`, mit Admin-Token `200` – für Ban, Overview und ERD.
- Tests mit `@TestSecurity` für alle drei Fälle.

### A4 · WebSocket nur mit gültigem Login — [ ]

> **Umsetzungsstand (53a775f, aa753fb):** Code fertig. `/ws/game` verlangt beim Upgrade einen Login; die Session gehört dem angemeldeten Spieler, `?playerId=` wird ignoriert, `create-battle` nimmt den Absender aus der Session. App schickt das Token als Header. Logs enthalten nur noch den Nachrichtentyp. Tests: `GameSocketTest` (`connectionWithoutLoginIsRefused`, `foreignPlayerIdInTheUrlDoesNotTakeOverTheSession`). WebApp ist abgeschaltet (siehe A2-Hinweis oben). **Offen:** Abnahme auf der Leo Cloud.

**Problem:** `GameSocket.java` (`/ws/game?playerId=…`) liest die Spieler-ID ungeprüft aus der URL. Wer eine fremde ID einträgt, ersetzt die Session des echten Spielers und kann in dessen Namen Battles annehmen, Ergebnisse melden und abstimmen.

**Umsetzung:**
- Beim Verbindungsaufbau den Access-Token mitschicken (Query-Parameter `access_token` oder als erste Nachricht; Header gehen bei `URLSessionWebSocketTask` auch). In `@OnOpen` den Token validieren und die Spieler-ID **daraus** ableiten. Ungültig → Session sofort schließen.
- Nachrichten, die eine Spieler-ID enthalten (Battle-Anfragen, Ergebnisse, Votes), gegen die Session-Identität prüfen und nicht dem Feld in der Nachricht vertrauen.
- Token nicht in Server-Logs schreiben. Aktuell werden URLs und IDs mit `System.out.println` geloggt.
- iOS: `GameSocketService.swift` und `Model.swift` (`/ws/game`) anpassen. WebApp: `GameSocketClient.js`.

**Abnahme:**
- Verbindung ohne Token oder mit ungültigem Token wird geschlossen.
- Verbindung mit Token von A und `playerId=B` in der URL: Der Server behandelt die Session als A, und die Session von B bleibt bestehen.
- `GameSocketTest` deckt diese Fälle ab.

### A5 · Standorte anderer Spieler schützen — [ ]

> **Umsetzungsstand (53a775f, aa753fb):** Code fertig. `nearby` um die gespeicherte eigene Position, max. 300 m, nur aktive (5 min oder verbunden) und sichtbare Spieler, Koordinaten auf ~50 m gerundet; fremde Profile ohne Koordinaten; Einstellung „Unsichtbar auf der Karte“; Positions-Events nur in der Nähe; WebSocket zu → offline. Tests: `SecurityChecklistTest`, UI-Test `SafetyTests.testSF03`. **Offen:** Abnahme mit zwei iPhones (Teil D).

**Problem:** `GET /api/players/nearby` in `PlayerRessources.java` nimmt beliebige `latitude`, `longitude` und `radius` und gibt **alle** Spieler darin mit exakten Koordinaten zurück (`PlayerDTO` enthält `latitude`/`longitude`). Mit großem Radius lassen sich die Live-Standorte aller Spieler abfragen. Bei minderjährigen Nutzern ist das das größte Risiko und ein DSGVO-Problem. Dasselbe gilt für Positions-Broadcasts über den WebSocket und für `GET /api/players/{id}`.

**Umsetzung:**
- Nur mit Login (A2). Als Mittelpunkt die serverseitig gespeicherte Position des eingeloggten Spielers verwenden, nicht die Query-Parameter.
- Radius serverseitig hart begrenzen (Vorschlag: 300 m). Größere Werte abschneiden.
- Nur Spieler zurückgeben, die in den letzten X Minuten aktiv waren (z. B. 5 min; `LastSeenFilter` existiert schon).
- Für fremde Spieler gerundete oder leicht verschobene Koordinaten ausliefern (z. B. auf ca. 50 m), keine exakten.
- Fremde Koordinaten aus `GET /api/players/{id}` und allen Profil-DTOs entfernen; dafür ein eigenes öffentliches DTO ohne Standort.
- WebSocket-Positionsupdates nur an Spieler im begrenzten Umkreis schicken, nicht an alle.
- Einstellung **„Unsichtbar“** (bzw. „nur für Freunde sichtbar“) im Profil; der Server respektiert sie bei `nearby` und beim WebSocket.
- Beim Logout bzw. App-Ende den Spieler als offline markieren, damit seine letzte Position nicht stehen bleibt.

**Abnahme:**
- `nearby` mit `radius=100000` liefert höchstens Spieler im 300-m-Umkreis der eigenen Position.
- Die zurückgegebenen Koordinaten fremder Spieler sind gerundet.
- Ein unsichtbarer Spieler taucht weder bei `nearby` noch per WebSocket bei anderen auf.
- Ein Spieler, der seit über 5 Minuten inaktiv ist, taucht nicht auf.

### A6 · Secrets und Konfiguration — [ ]

> **Umsetzungsstand (177e4dd, 53a775f):** Code fertig. `%prod` ohne Fallback-Passwörter, `ProdSecretsGuard` bricht den Start ab, wenn `KEYCLOAK_CLIENT_SECRET`/DB-Passwort fehlen oder Standardwerte sind oder der Dev-Login aktiv ist (lokal geprüft: Start schlägt fehl). `*` aus CORS entfernt, `.env.local` aus dem Git (`.env.example` als Vorlage), `secret-example.yaml` nur Platzhalter. **Offen:** echte Secrets auf der Leo Cloud prüfen/rotieren, Keycloak-Admin mit starkem Passwort + 2FA.

**Problem:** Fallbacks in `application.properties`: `KEYCLOAK_CLIENT_SECRET:secret`, Datenbank `postgres/postgres`. In `k8s/secret-example.yaml` stehen `admin` bzw. `postgres`. `.env.local` ist im Git. Der CORS-Standardwert enthält `*` zusammen mit `allow-credentials=true`.

**Umsetzung:**
- Prüfen, dass das echte Kubernetes-Secret `challengr-secrets` auf der Leo Cloud **starke, eigene** Werte hat, insbesondere `KEYCLOAK_ADMIN_PASSWORD`, `POSTGRES_PASSWORD` und `KEYCLOAK_CLIENT_SECRET`. Falls nicht, rotieren.
- Fallback-Werte für Secrets im `%prod`-Profil entfernen, damit der Server ohne sie nicht startet.
- `*` aus dem CORS-Standardwert entfernen.
- `.env.local` aus dem Git entfernen (`git rm --cached`) und in `.gitignore` aufnehmen. Darin stehen nur lokale Dev-Werte, aber das Muster soll weg.
- Die Keycloak-Admin-Konsole nicht ohne Not öffentlich lassen; mindestens ein starkes Passwort und 2FA für den Admin.

**Abnahme:**
- Die Keycloak-Admin-Konsole ist mit `admin`/`admin` **nicht** erreichbar.
- Ein Backend-Start im Prod-Profil ohne gesetztes `KEYCLOAK_CLIENT_SECRET` schlägt fehl.
- `git ls-files .env.local` ist leer.

### A7 · Berechtigungstexte, Privacy-Manifest, Verschlüsselung (iOS) — [ ]

> **Umsetzungsstand (1735fad):** Code fertig. Neue Texte (Mikrofon schreibt nachweislich nach `/dev/null`, Kamera wertet nur lokal aus), „Immer“-Text entfernt, `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption = NO`, nur iPhone. Keine weiteren Required-Reason-APIs im Code gefunden. **Offen:** Archive-Upload zu App Store Connect ohne ITMS-Warnungen.

**Problem:** In `project.pbxproj` stehen `NSLocationWhenInUseUsageDescription = "need your location"` und `NSMicrophoneUsageDescription = "Diese App benötigt ihr mikrofon"`. Das ist zu vage, und Apple lehnt solche Texte auch bei TestFlight ab. `NSLocationAlwaysAndWhenInUseUsageDescription` ist gesetzt, obwohl die App „Immer“ nie anfragt. Ein `PrivacyInfo.xcprivacy` fehlt, obwohl die App `UserDefaults` nutzt (Upload-Warnung ITMS-91053).

**Umsetzung:**
- Standort: „Challengr zeigt dich auf der Karte und findet Gegner und Hotspots in deiner Nähe.“
- Mikrofon: „Für die Lautstärke-Challenge misst Challengr, wie laut es gerade ist. Es wird nichts aufgenommen oder gespeichert.“ Prüfen, ob das stimmt.
- Kamera: Text ist gut. Prüfen, dass Kamerabilder wirklich nur lokal ausgewertet und nicht hochgeladen werden.
- Den „Immer“-Text entfernen.
- `PrivacyInfo.xcprivacy` anlegen: `NSPrivacyAccessedAPICategoryUserDefaults` mit Grund `CA92.1`, plus die gesammelten Datentypen (genauer Standort, Name, Benutzer-ID, Spielfortschritt; alle an die Identität gebunden, kein Tracking). Weitere Required-Reason-APIs im Code suchen (z. B. Datei-Zeitstempel, `systemUptime`).
- `ITSAppUsesNonExemptEncryption = NO` setzen (nur HTTPS).
- `TARGETED_DEVICE_FAMILY` auf `1` (nur iPhone), solange das iPad-Layout nicht getestet ist.

**Abnahme:**
- Ein Archive-Upload zu App Store Connect läuft ohne ITMS-Warnungen durch.
- Die Berechtigungsdialoge auf einem frischen iPhone zeigen die neuen deutschen Texte.

---

## Teil B – Muss vor dem öffentlichen App Store

B1 und B3 nach Möglichkeit schon vor TestFlight erledigen.

### B1 · Konto in der App löschen (Apple-Regel 5.1.1(v)) — [ ]

> **Umsetzungsstand (db3d4da):** Code fertig. `DELETE /api/players/me` löscht Keycloak-Konto (in Prod Pflicht) und alle Daten, Battles nur noch mit „Gelöschter Spieler“. App: Einstellungen → „Konto löschen“. Tests: `AccountDeletionTest`, UI-Test `SafetyTests.testSF04`. **Offen:** Der Keycloak-Client `challengr-admin-api` braucht die Rolle `manage-users`; Abnahme auf der Leo Cloud.
- In `Views/SettingsView.swift`: Button „Konto löschen“ mit Bestätigungsschritt.
- Backend `DELETE /api/players/me` (nur mit Token): Spieler, Freundschaften, Anfragen, Geschenke, Hotspot-Check-ins und Items löschen; Battles anonymisieren. Danach den Keycloak-User löschen; `control/KeycloakAdminUserClient.java` existiert schon.
- Lokale Daten in der App (`UserDefaults`-Keys `playerId.*`) löschen und zurück zum Login.
- **Abnahme:** Nach dem Löschen ist kein Login mit dem Account mehr möglich, und die Datenbank enthält keine Daten mehr zu dieser Player-ID.

### B2 · Melden und Blockieren (Apple-Regel 1.2) — [ ]

> **Umsetzungsstand (b8d7f25):** Code fertig. Melden (Grund + Text) und Blockieren im Spieler-Popup und Freundesprofil, „Blockierte Spieler“ in den Einstellungen; der Server setzt Blockierungen bei nearby, Herausfordern, Freundschaft und Emotes durch; Dashboard-Seite „Meldungen“ mit Sperren; Namensfilter. Tests: `SafetyTest`, UI-Tests `SafetyTests.testSF01/02`.
- Im Profil eines fremden Spielers „Melden“ (mit Grund) und „Blockieren“.
- Blockierte Spieler sehen sich gegenseitig nicht mehr auf der Karte, können sich nicht herausfordern und keine Freundschaftsanfragen schicken. Das prüft der Server.
- Meldungen erscheinen im Dashboard, inklusive Sperren über das bestehende Ban-System.
- Benutzernamen gegen eine Schimpfwortliste prüfen (Registrierung und Umbenennen).
- **Abnahme:** A blockiert B → B taucht bei A nicht mehr in `nearby` auf und umgekehrt; eine Herausforderung B → A wird vom Server abgelehnt.

### B3 · Datenschutzerklärung und Einwilligung — [ ]

> **Umsetzungsstand (76b8085):** Code fertig. Erklärung unter `https://it220257.cloud.htl-leonding.ac.at/datenschutz.html` (vom Dashboard ausgeliefert), verlinkt im Onboarding und in den Einstellungen; Onboarding-Schritt „Dein Standort & deine Daten“ mit Bestätigung „mindestens 14“. **Offen:** In `Dashboard/public/datenschutz.html` Verantwortlichen und Kontakt-E-Mail eintragen (gelb markierte Platzhalter).
- Datenschutzerklärung als Webseite (z. B. auf der eigenen Firmen-Webseite unter `/challengr/datenschutz`) mit: Verantwortlicher, welche Daten (Standort, Name, Spielstand, technische Logs), Zweck, Speicherort (Server der HTL Leonding, Österreich), Speicherdauer, Löschung, Rechte nach DSGVO, Kontakt.
- In der App: Link in den Einstellungen und beim ersten Start. Vor der ersten Standortfreigabe ein kurzer Hinweis, wer den eigenen Standort sieht.
- Mindestalter festlegen. In Österreich dürfen Jugendliche ab 14 selbst einwilligen. Darunter braucht es die Zustimmung der Eltern; einfacher ist es, die App für den Test auf 14+ zu beschränken.
- **Abnahme:** Die URL ist öffentlich erreichbar und in der App verlinkt.

### B4 · Speicherdauer — [ ]

> **Umsetzungsstand (db3d4da):** Code fertig. Nur die aktuelle Position wird gespeichert; WebSocket-Logs ohne Inhalte; `InactiveAccountCleanup` löscht Konten nach 365 Tagen Inaktivität (in der Datenschutzerklärung genannt). Test: `InactiveAccountCleanupTest`.
- Standortdaten nur so lange speichern, wie sie fürs Spiel gebraucht werden (aktuelle Position, keine Bewegungshistorie). Prüfen, ob irgendwo Positionen historisiert oder geloggt werden (Server-Logs, `System.out.println` mit Koordinaten).
- Inaktive Accounts nach einer festen Frist löschen oder anonymisieren und das in der Datenschutzerklärung angeben.

### B5 · Prüfer-Zugang — [ ]

> **Umsetzungsstand:** noch offen (erst für den öffentlichen App Store nötig).
- Ein Demo-Account plus ein Weg, ohne zweiten Spieler in der Nähe ein Battle zu sehen (Bot-Gegner oder Übungsmodus). Apple prüft aus den USA.

---

## Teil C – Organisatorisch (kein Code)

- [ ] Betreuungslehrer bzw. Schulleitung haben einem schulweiten Test mit Standortdaten zugestimmt.
- [ ] Geklärt, ob der Leo-Cloud-Server für einen Test mit vielen Nutzern verwendet werden darf.
- [ ] Altersgrenze für den Test festgelegt (Vorschlag: ab 14) und in der TestFlight-Beschreibung genannt.
- [ ] Ansprechperson für Meldungen und Löschanfragen festgelegt; die Kontakt-Mail steht in der Datenschutzerklärung.
- [ ] Apple Developer Account (99 €/Jahr) ist aktiv, EU-Händlerstatus in App Store Connect angegeben.
- [ ] Datenbank-Backup vor dem Teststart eingerichtet (z. B. täglicher `pg_dump` als Kubernetes-CronJob).

---

## Teil D – Abnahmetest vor dem Verteilen des TestFlight-Links

Mit zwei echten iPhones (Spieler A und B) gegen den Leo-Cloud-Server, Release-Build über TestFlight, beide frisch installiert:

1. [ ] Beide registrieren sich neu über Keycloak; die Berechtigungsdialoge zeigen die neuen Texte.
2. [ ] Beide sehen sich auf der Karte, wenn sie nebeneinander stehen. In 500 m Abstand sehen sie sich nicht.
3. [ ] A schaltet „Unsichtbar“ ein → B sieht A nicht mehr.
4. [ ] Battle A gegen B komplett durchspielen (Real-Life, Wissen, Friendly); Punkte und Trophäen stimmen.
5. [ ] Backend neu starten → Accounts und Punkte sind noch da.
6. [ ] Mit `curl` ohne Token: alle `/api`-Endpoints außer den bewusst öffentlichen liefern `401`; `/ws/game?playerId=<A>` wird geschlossen.
7. [ ] Mit dem Token von B das Profil von A ändern, für A einkaufen oder A sperren → jeweils `403`.
8. [ ] `nearby` mit riesigem Radius → nur Spieler im Umkreis, mit gerundeten Koordinaten.
9. [ ] B blockiert A → keine Sichtbarkeit und keine Herausforderungen mehr (falls B2 schon umgesetzt ist).
10. [ ] B löscht sein Konto → Login nicht mehr möglich, keine Daten mehr in der Datenbank (falls B1 schon umgesetzt ist).
11. [ ] `./mvnw test` ist grün, und der iOS-Build hat keine Warnungen zu Berechtigungen oder Privacy-Manifest.

Erst wenn A1–A7, Teil C und Teil D abgehakt sind, wird der öffentliche TestFlight-Link verteilt.
