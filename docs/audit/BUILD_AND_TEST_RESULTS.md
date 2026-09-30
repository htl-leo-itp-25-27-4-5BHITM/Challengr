# BUILD AND TEST RESULTS – Challengr iOS (Phase 3)

> Alle Zahlen stammen aus echten Läufen am 30.09.2026 (siehe [EXECUTION_LOG](EXECUTION_LOG.md), Rohlogs unter [`logs/`](logs/)).

## 1. Testumgebung

| | |
|---|---|
| Xcode | 26.0.1 (17A400), Swift-5-Modus |
| Simulatoren | iPhone 17 Pro (iOS 26.0, Hauptgerät), iPhone 16e, iPad Pro 11" (M4) |
| Scheme / Targets | `Challengr` → App `Challengr`, Unit-Tests `ChallengrTests` |
| Backend für UI-Tests | lokale Kopie des Repo-Backends, Quarkus-Dev-Modus, H2 im Speicher, Testdaten aus `import.sql` |
| Gegenspieler | Node-Skript `opponent.mjs` (echte WebSocket-Verbindungen zum lokalen Backend) |

## 2. Build

| Build | Befehl | Ergebnis | Dauer | Warnungen |
|---|---|---|---|---|
| Clean Build Debug (Simulator) | `xcodebuild clean build` | ✅ BUILD SUCCEEDED | 17 s | **12** Swift-Warnungen |
| Strict Concurrency (Override) | `… SWIFT_STRICT_CONCURRENCY=complete` | ✅ BUILD SUCCEEDED | – | **58** Meldungen |

**Relevante Warnungen** (vollständig in `logs/01_build_warnings.txt`):

| Datei:Zeile | Warnung | Bedeutung |
|---|---|---|
| `LoudnessChallengeView.swift:295` | MainActor-isolierte `Equatable`-Konformität in nicht-isoliertem Kontext | **wird in Swift 6 ein Fehler** |
| `LoudnessChallengeView.swift:236` | `integral` wird nie benutzt | toter Rechenweg in der Lautstärke-Auswertung |
| `Model.swift:45`, `TrophyRoadView.swift:6` | `let id = UUID()` wird nicht dekodiert | Identität ändert sich bei jedem Laden |
| `CameraChallengeView.swift:414-415` | `videoOrientation` seit iOS 17 veraltet | Deployment Target ist 17.6 |
| `MapView.swift:380, 407`, `TrophyRoadView.swift:166` | `onChange(of:perform:)` veraltet | – |
| `UserProfileView.swift:194, 216, 246` | `plotAreaFrame` veraltet | – |

**Strict Concurrency** (Auszug, vollständig in `logs/02_strict_concurrency_warnings.txt`): 17 Meldungen in `GameSocketService` (MainActor-Zustand wird aus `@Sendable`-Closures von URLSession verändert), 12 in `LoudnessChallengeView`, 4 in `KnowledgeBattleView`, je 1–3 in Sprint/Shake/Pushup/SoundMeter/Camera/SoundManager.

## 3. Automatisierte Tests

### 3.1 Übersicht

| Suite | Art | Ausgeführt | ✅ Bestanden | ❌ Fehlgeschlagen | Quelle |
|---|---|---|---|---|---|
| `ChallengrTests` (Repo) | Unit (XCTest) | 47 | 47 | 0 | `logs/03_ios_unit_tests.log` |
| Backend (Repo, Kopie) | JUnit + WS-E2E | 75 | 75 | 0 | `logs/04_backend_tests.log` |
| **Audit-UI-Tests** (Klon) | XCUITest E2E | 42 Testmethoden in 50 Läufen (72 Testfälle in der Matrix) | siehe [TEST_MATRIX](TEST_MATRIX.md) | | `logs/07`, `10`, `11`, `16_*` |
| Accessibility-Audit | `performAccessibilityAudit` | 9 Screens | – | **218 Befunde** | `logs/08_accessibility_audit_raw.jsonl` |
| Performance | XCTMetric, `leaks`, `xctrace` | 5 Messungen | – | – | [PERFORMANCE_REPORT](PERFORMANCE_REPORT.md) |

### 3.2 Code-Abdeckung (App, Unit-Tests)

**3,9 %** (960 von 24 584 Zeilen). Vollständig in `logs/03_ios_coverage_by_file.txt`.

| Bereich | Abdeckung |
|---|---|
| `Logic/BattleLogic.swift`, `Logic/BattleScreen.swift` | 100 % |
| `Model.swift` | 94 % |
| `WebSocket/GameSocketService.swift` | 36 % |
| `Services/SoundManager.swift` | 34 % |
| `MapView.swift` (1 676 Zeilen) | **0 %** |
| alle Battle-Views, Shop, Profil, Freunde, Trophy Road | **0 %** |
| `FriendsService`, `PlayerLocationService`, `FriendsInboxStore` | < 1 % |

### 3.3 Kritische Lücken in der vorhandenen Testabdeckung

1. **Keine UI-Tests im Repo**. Die Defekte BUG-02, BUG-03 und BUG-05 wurden erst durch die Audit-UI-Tests sichtbar.
2. Keine Tests für den Battle-Zustand in `MapView` (eingehend/ausgehend/aktiv). Das ist der Bereich mit den schwersten Fehlern.
3. Services sind nicht austauschbar (fest `URLSession.shared`), Netzwerkfehler also nicht testbar.
4. Keine Tests für die Sensor-Challenges (Messung, Timer).
5. Die CI führt keinen dieser Tests aus (`.github/workflows/ci.yaml` ist ein Platzhalter).

## 4. Fehlgeschlagene Tests: Ursache und Einordnung

| Test | Ursache | Einordnung |
|---|---|---|
| GP14 Wissen: beide falsch | Client sperrt nach einer Antwort, Backend wertet nur richtige Antworten aus → kein Ergebnis | **App-Defekt** → BUG-03 |
| GP17 Dritter Spieler während Battle | `currentBattleId` wird durch neue Anfrage überschrieben; Backend-Log: `DONE_SURRENDER` für Battle 15 statt 14 | **App-Defekt** → BUG-02 |
| FU01 Neustart mit offener Anfrage | Zustand nur im Speicher; die Annahme der alten Anfrage wird ignoriert | **App-Defekt** → BUG-05 |
| FU02 Neustart im Battle | Battle-Oberfläche nicht wiederhergestellt (das Ergebnis kommt aber an) | **App-Defekt** → BUG-06 |
| SC06 Popup schließen | Tippen neben das Spieler-Popup schließt es nicht | **UX-Defekt** → BUG-12 |
| GP08 (Teil 2) | Zweite Anfrage per UI nicht auslösbar, weil das Overlay die Karte blockiert (korrektes Verhalten) | **Testfehler** – durch FU01 ersetzt |
| SC02 (Toggle) | XCUITest-Standard-Tap trifft den SwiftUI-Toggle nicht | **Testfehler** – RT01 bestanden |
| SC03 | Probe-Anfrage aus SC02 wurde (korrekt) nachgeliefert und verdeckte das Profil | **Testwechselwirkung** – RT02 wiederholt |
| RT02 (1./2. Lauf) | Profil-Button heißt mit Badge nur „1“ → Selektor | **Testproblem**, zugleich A11y-Befund BUG-10 |
| GP03 (1. Lauf) | Selektor traf MapKit-Element statt Pin | **Testfehler** – nach Korrektur bestanden |

## 5. Statische Analyse

- Keine Linter im Projekt; SwiftLint und Periphery waren in der Umgebung nicht installiert.
- Ersatzweise: Compiler-Warnungen (Standard und strikt), gezielte Code-Suchen (Force-Unwraps, Timer, Tasks, `print`, Auth-Header, tote Symbole, unbenutzte Assets). Ergebnisse siehe [SWIFT_CODE_AUDIT](SWIFT_CODE_AUDIT.md).
