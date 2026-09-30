# EXECUTION LOG – Challengr iOS Audit

> Chronologisches Protokoll aller ausgeführten Befehle, Testläufe, Fehler und Einschränkungen.
> Zeitzone: Europe/Vienna, Datum 30.09.2026. Rohlogs liegen unter [`logs/`](logs/).

## 0. Grundsätze der Durchführung

- **Am Repository wurde nichts geändert.** Die einzigen neuen Dateien liegen unter `docs/audit/`.
  `git status` nach dem Audit zeigt zusätzlich zwei Änderungen, die **bereits vor Beginn** vorhanden waren (erster `git status` des Audits): `Swift Kopie/…/project.pbxproj` sowie `UserInterfaceState.xcuserstate`. Letztere schreibt das geöffnete Xcode selbst.
- Alle Eingriffe, die für Tests nötig waren, fanden in einem **isolierten Klon im Scratchpad** statt (`…/scratchpad/audit/app` und `…/scratchpad/audit/backend`). Sie sind unten einzeln dokumentiert.
- Gegen die **Produktivumgebung** (LeoCloud, echtes Keycloak) wurde **nichts** ausgeführt. Kein Login, keine Datenänderung.
- Build-Artefakte (DerivedData, xcresult) liegen ebenfalls im Scratchpad.

## 1. Umgebung

| Komponente | Version |
|---|---|
| macOS | 15.7.3 (24G419) |
| Xcode | 26.0.1 (17A400) |
| Simulator-Laufzeit | iOS 26.0 (23A343), die einzige installierte |
| Simulatoren | iPhone 17 Pro (Hauptgerät), iPhone 16e (kleinstes verfügbares iPhone), iPad Pro 11" (M4) |
| Java / Maven | OpenJDK 25.0.2, Maven 3.9.11 (Wrapper) |
| Node | 25.2.1 (Gegenspieler-Skript) |
| Nicht verfügbar | SwiftLint, Periphery, echtes iPhone, Keycloak-Testkonto, iOS < 26 |

## 2. Befehle und Ergebnisse

### 2.1 Discovery
```bash
git log --oneline -8                     # HEAD = 8eccb7f
find Swift/Challengr -name "*.swift" | xargs wc -l
cat .github/workflows/ci.yaml            # Platzhalter: java Hello.java
xcrun simctl list devices available
```

### 2.2 Clean Build (Original-Repo, Artefakte im Scratchpad)
```bash
xcodebuild clean build -project Challengr.xcodeproj -scheme Challengr \
  -destination 'platform=iOS Simulator,id=<iPhone 17 Pro>' \
  -derivedDataPath <scratch>/dd-orig CODE_SIGNING_ALLOWED=NO
```
→ **BUILD SUCCEEDED** in 17 s, 12 Swift-Warnungen (`logs/01_clean_build.log`, `logs/01_build_warnings.txt`).

### 2.3 Statische Analyse (Strict Concurrency, nur als Kommandozeilen-Override)
```bash
xcodebuild clean build … SWIFT_STRICT_CONCURRENCY=complete
```
→ BUILD SUCCEEDED, **58 Meldungen** (`logs/02_strict_concurrency_warnings.txt`).

### 2.4 Vorhandene Unit-Tests + Coverage (Original-Repo)
```bash
xcodebuild test … -enableCodeCoverage YES -resultBundlePath <scratch>/unit.xcresult
xcrun xccov view --report --files-for-target Challengr.app <scratch>/unit.xcresult
```
→ **47/47 bestanden**, App-Abdeckung **3,9 %** (`logs/03_ios_unit_tests.log`, `logs/03_ios_coverage_by_file.txt`).

### 2.5 Backend-Tests (Kopie des Backends)
```bash
cd <scratch>/backend && ./mvnw test
```
→ **75/75 bestanden** in 23 s (`logs/04_backend_tests.log`).

### 2.6 Lokales Test-Backend
```bash
./mvnw quarkus:dev -Dquarkus.profile=test -Dquarkus.http.port=8080 …
```
- 1. Versuch **fehlgeschlagen**: `Unable to find a JDBC driver … 'h2'`, weil der H2-Treiber im Repo nur `scope=test` hat.
- **Harness-Eingriff H1** (nur in der Kopie): `quarkus-jdbc-h2` ohne `test`-Scope. 2. Versuch: läuft nach ~12 s, Testdaten aus `import.sql`, OIDC aus (Test-Profil).

### 2.7 Sicherheitsprüfung REST (nur lokal)
```bash
curl http://localhost:8080/api/players                     # ohne Token
curl -X PUT /api/players/demo-2 -d '{"name":"GEHACKT",…}'  # fremden Spieler ändern
curl /api/challenges ; curl /api/admin/overview
```
→ alle **HTTP 200**, fremder Spieler umbenannt und danach zurückgesetzt (`logs/05_security_rest_unauth.txt`).

### 2.8 Harness für UI-Tests (nur im App-Klon)

| ID | Eingriff | Zweck |
|---|---|---|
| H2 | `BackendConfig.baseURL` liest optional `AUDIT_BACKEND_URL` | App spricht mit lokalem Backend statt Cloud |
| H3 | `KeycloakAuthService.init()` setzt bei `AUDIT_PLAYER_ID` direkt eine Session | Keycloak-Login umgehen (kein Testkonto, keine Produktivdaten) |
| H4 | `AuditInfo.plist` mit `NSAllowsArbitraryLoads` + `INFOPLIST_FILE` | http/ws zu `localhost` erlauben |
| H5 | neues Target `ChallengrUITests` (XCUITest) | UI automatisiert bedienen, echte Screenshots |
| H6 | `opponent.mjs`: Node-Steuerserver auf Port 9099 | scriptbarer zweiter/dritter Spieler per WebSocket |

Alle übrigen App-Dateien sind **byte-identisch** mit dem Repo. Alles, was nach dem Login passiert, läuft also mit dem Original-Code.

Vorbereitung Simulator:
```bash
xcrun simctl location <udid> set 48.268320,14.251380
curl -X POST /api/players -d '{"keycloakId":"audit-1","name":"AuditTester",…}'
```

### 2.9 UI-Testläufe

| Lauf | Befehl (gekürzt) | Ergebnis | Log |
|---|---|---|---|
| Explore | `-only-testing:ChallengrUITests/ExploreTests` | 1/1, Hierarchie-Dump | – |
| Gameplay #1 | `…/GameplayTests` | **abgebrochen** nach GP03: Selektor-Fehler im Test-Helfer (MapKit-Element `VKPointFeature` hat denselben Namen wie der Pin) → Helfer korrigiert | `gameplay1_aborted.log` (Scratch) |
| Gameplay #2 | `…/GameplayTests` | **0 Tests ausgeführt**: Testdatei wurde während des Builds angelegt (synchronisierter Ordner) → Neustart, danach nur noch „staged“ angelegt | Scratch |
| Gameplay #3 | `…/GameplayTests` | **19 Tests: 16 bestanden, 3 fehlgeschlagen** (2 App-Defekte, 1 Testfehler) | `logs/07_ui_gameplay_tests.log` |
| Welle 2 | `ScreenTests`, `FollowUpTests`, `AccessibilityAuditTests` | 14 Tests: 9 bestanden, 5 fehlgeschlagen (2 App-Defekte, 3 Test-/Wechselwirkungsprobleme) | `logs/10_ui_screens_followup_a11y.log` |
| Welle 3 | `RetestTests`, `LayoutTests`, `PerformanceTests` | 8 Tests: 7 bestanden, RT02 Selektor-Problem | `logs/11_ui_retest_layout_perf.log` |
| RT02 (2×) | einzeln, Selektor korrigiert | Profil + Trophy Road ok, Freunde-Seite gesperrt (Befund BUG-13) | Scratch |
| Explore 2 | Button-Beschriftungen unten | Profil-Button heißt „1“ (mit Badge) | Scratch |
| Layout dunkel | `LayoutTests/testLAY01` mit `simctl ui appearance dark` + `content_size accessibility-extra-extra-extra-large` | bestanden (Screenshots zeigen BUG-04, BUG-14) | `logs/16_ui_layout_dark.log` |
| Layout 16e / iPad | `LayoutTests` auf iPhone 16e und iPad Pro 11" | je 2/2 bestanden (Screenshots zeigen BUG-08, BUG-16) | `logs/16_ui_layout_*.log` |

## 3. Aufgetretene Probleme bei der Durchführung

1. **H2-Treiber fehlt im Dev-Modus** → Harness-Eingriff H1.
2. **Pin-Selektor** traf das MapKit-Element statt des SwiftUI-Pins → Test-Helfer korrigiert, Lauf wiederholt.
3. **Leerer Testlauf** durch gleichzeitiges Anlegen einer Testdatei → Vorgehen umgestellt.
4. **Testwechselwirkung SC02 → SC03:** Die nach dem Logout gesendete Probe-Anfrage wurde beim nächsten App-Start (korrekt) nachgeliefert und verdeckte das Profil → SC03 als RT02 wiederholt.
5. **SwiftUI-Toggle** reagierte nicht auf den Standard-Tap von XCUITest → RT01 mit Koordinaten-Tap.
6. Die Mitteilung in GP19 war sichtbar (Screenshot), wurde aber vom Selektor nicht gefunden → Bewertung anhand des Screenshots.

## 4. Messungen außerhalb von XCTest

```bash
# Leaks nach 5 Anfrage-/Abbruch-Zyklen
SIMCTL_CHILD_AUDIT_BACKEND_URL=… xcrun simctl launch <udid> at.htl.leonding.challengr.binder -hasSeenOnboarding YES
leaks <pid>                                   # → 0 leaks, 104,1 MB Footprint (logs/12_*)

# Instruments Time Profiler (1. und 2. Versuch: "Cannot find process" → --device fehlte)
xcrun xctrace record --template 'Time Profiler' --device <udid> --attach Challengr --time-limit 15s --output tp.trace
xcrun xctrace export --input tp.trace --xpath '…/table[@schema="time-profile"]'   # 16 Samples
xcrun xctrace export --input tp.trace --xpath '…/table[@schema="hang-risks"]'     # 0 Hang-Risiken
```

## 5. Simulator-Zustand nach dem Audit

- Erscheinungsbild und Schriftgröße auf dem iPhone 17 Pro wurden auf **hell / large** zurückgesetzt.
- Simulierte Position bleibt auf 48.268320, 14.251380. Das kann in Xcode zurückgesetzt werden: *Features → Location → None*.
- Auf den Simulatoren ist zusätzlich die **Audit-Harness-App** (gleiche Bundle-ID wie die Swift-App: `at.htl.leonding.challengr.binder`) installiert. Ein normaler Build aus dem Repo überschreibt sie.
- Das lokale Test-Backend und das Gegenspieler-Skript werden am Ende beendet. Scratchpad-Dateien sind außerhalb des Repos.

## 6. Verwendete Artefakte

| Artefakt | Ort |
|---|---|
| Screenshots (95, verkleinert auf 600 px JPEG) | `docs/audit/screenshots/` |
| Rohlogs, Beobachtungen (`jsonl`) | `docs/audit/logs/` |
| Original-Screenshots (PNG), xcresult-Bundles, Time-Profiler-Trace, Harness-Code | Scratchpad (nicht im Repo) |
