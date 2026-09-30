# PERFORMANCE REPORT – Challengr iOS (Phase 6)

> **Messumgebung:** iOS-Simulator (iPhone 17 Pro, iOS 26.0) auf macOS 15.7.3, **Debug-Build**, lokales Backend.
> Simulator-Messungen sagen etwas über **Trends** (Wachstum, Leaks, Hänger), aber **nichts** über absolute Werte auf echten Geräten: Die CPU ist die des Macs, es gibt kein Thermal-Throttling, GPU und Energie weichen ab. Messungen auf echten Geräten fehlen (BLOCKED, kein Gerät).

## 1. Echte Messungen

### 1.1 App-Start (`XCTApplicationLaunchMetric`, 5 Starts)

| Metrik | Werte (s) | Mittel |
|---|---|---|
| Bis erster reaktionsfähiger Frame | 3,52 · 2,06 · 3,18 · 2,29 · 1,72 | **2,56 s** (RSD 26,7 %) |

**Einordnung:** Für einen Debug-Build im Simulator akzeptabel. Die große Streuung passt dazu, dass beim Start zugleich Standort, WebSocket, 5 Kategorie-Anfragen, Rang-Farben und Profil-Daten geladen werden (`MapView.setupSocket`, `reloadOwnPlayerData`: 7 REST-Aufrufe parallel).
**Methode:** `PerformanceTests.testPERF01_LaunchTime` · **Log:** `logs/11_ui_retest_layout_perf.log`

### 1.2 Speicher und CPU beim Navigieren (Shop ↔ Einstellungen, 5 Durchgänge à 3 Zyklen)

| Metrik | Durchgang 1 → 5 | Mittel |
|---|---|---|
| Physischer Speicher (absolut) | 119,6 → 120,6 → 121,5 → 122,0 → **122,6 MB** | 121,3 MB |
| Speicher-Spitze | 121,1 → **124,3 MB** | 122,9 MB |
| CPU-Zeit | 3,59 · 3,42 · 3,00 · 2,96 · 3,08 s | 3,21 s |

**Befund (gemessen):** Der Speicher wächst **stetig um ≈ 0,75 MB pro Durchgang**. Das ist klein, aber monoton. Die Ursache ist nicht ermittelt. Ein Kandidat: `ShopView.loadShop()` (Zeile 164) lädt Items und Besitz bei jedem Öffnen neu, und die Asset-Bilder landen im Bild-Cache des Systems. Für Schulsessions ohne Bedeutung, für lange Sessions beobachten.

### 1.3 Speicher über wiederholte Battle-Runden (Anfrage → Annehmen → Aufgeben → Ergebnis → Karte)

| Metrik | Runde 1 → 5 | Mittel |
|---|---|---|
| Physischer Speicher (absolut) | 118,5 → 119,1 → 119,4 → 120,1 → **120,2 MB** | 119,5 MB |
| Speicher-Spitze | 127,1 → **128,9 MB** | 128,1 MB |

6 Runden erfolgreich (`completedRounds = 6`). Leichtes Wachstum (≈ 0,4 MB/Runde), kein Sprung.

### 1.4 Speicherlecks (`leaks`)

Nach dem Start und 5 Zyklen „Anfrage empfangen → vom Gegner abgebrochen“:
```
Physical footprint:         104.1M
Physical footprint (peak):  105.3M
Process 60475: 0 leaks for 0 total leaked bytes.
```
→ **Keine Leaks gefunden** (`logs/12_leaks_after_requests.txt`).

### 1.5 Instruments – Time Profiler (15 s Karte im Ruhezustand)

`xcrun xctrace record --template 'Time Profiler' --device <sim> --attach Challengr --time-limit 15s`

| Ergebnis | Wert |
|---|---|
| CPU-Samples in 15 s (1 ms Intervall) | **16** (≈ 0,1 % CPU) |
| Hang-Risiken (Main Thread) | **0** |

Im Leerlauf ist die App trotz 4-s-Polling sehr sparsam. Die Samples verteilen sich auf Netzwerk-Idle (`HTTPConnectionCache::performIdleSweep`, `kevent`), Speicherverwaltung und XPC. Es gibt keinen App-Hotspot (`logs/13_time_profiler_summary.txt`).

### 1.6 Stabilität

- In **50 UI-Testläufen** (≈ 45 min App-Laufzeit, dutzende Battles, Hintergrund/Vordergrund, Neustarts, 6-fache Schnell-Taps) gab es **keinen einzigen Absturz**.
- Hintergrund → Vordergrund: Zustand und Popup bleiben erhalten (GP18). Die Verbindung wird nach Rückkehr wieder aufgebaut (GP19).

## 2. Theoretische Risiken (Code, nicht gemessen)

| ID | Risiko | Erwartete Wirkung | Beleg |
|---|---|---|---|
| P-01 | Standort mit `kCLLocationAccuracyBest` **ohne `distanceFilter`**, jede Änderung ist ein PUT. Während Sprint und Check-In laufen **2 zusätzliche `CLLocationManager`**, jeder sendet ebenfalls PUTs. Nirgends `stopUpdatingLocation`. | Akku und Datenvolumen auf echten Geräten, Last aufs Backend bei vielen Spielern | `LocationHelper.swift:27-51` |
| P-02 | Polling-Kaskade: Nähe alle 4 s, Freunde 30 s + eingehend 5 s (solange die Freunde-Seite offen ist), Badge 60 s, plus WebSocket-Events → Nähe-Refresh (gedrosselt 2 s). | Netzlast, Akku | `MapView.swift:637-645`, `FriendsListView.swift:257-274` |
| P-03 | `PlayerAnnotation.id = UUID()` → **alle Pins werden alle 4 s neu aufgebaut** (neue Identität). | Unnötige SwiftUI-/MapKit-Updates, besonders bei vielen Spielern | `MapView.swift:19-20` |
| P-04 | Beim Öffnen der Freunde-Seite **2 parallele `loadAll`**, Freunde einzeln geladen (N+1). | doppelte Anfragen | `FriendsListView.swift:249-274` |
| P-05 | Backend `findNearbyPlayers` lädt **alle** Spieler und filtert in Java. Wird pro Positions-Update und pro Nähe-Abfrage aufgerufen. | skaliert O(n) je Anfrage, bei Schultests unkritisch | `PlayerRepository.java:164-175` |
| P-06 | Große Assets: Avatare je ≈ 1 MB PNG, ungenutztes 0,9-MB-JPG, 46 ungenutzte MP3 (von 62). | App-Größe (+ ≈ 8 MB unnötig) | Asset-Katalog |
| P-07 | 62 `print()`-Aufrufe, darunter jede WebSocket-Nachricht, auch im Release-Build. | geringe CPU-Last, Log-Rauschen | `GameSocketService.swift` |
| P-08 | Kompass-Task und Heading-Updates laufen nach Verlassen der View weiter. | Akku | `CompassChallengeView.swift:159, 205-213` |

## 3. Nicht messbar in dieser Umgebung

- Framerate und Hitches bei Animationen (Template „Animation Hitches“ nur auf echten Geräten)
- Energieverbrauch (Energy Log nur auf echten Geräten)
- Verhalten auf langsamen, älteren Geräten und unter iOS < 26
- Speicherverhalten über sehr lange Sitzungen (> 30 min)

## 4. Fazit

Im Simulator ist die App **stabil, leckfrei und im Leerlauf sparsam**. Das Speicherwachstum ist klein. Die größten Performance-Hebel sind nicht gemessen, sondern im Code sichtbar: Standort-Updates ohne Filter (P-01), die Polling-Kaskade (P-02) und die Pin-Neuaufbauten (P-03). Sie sollten auf echten Geräten mit Instruments (Energy Log, Location) überprüft werden, bevor viele Spieler gleichzeitig spielen.
