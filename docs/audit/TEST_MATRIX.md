# TEST MATRIX – Challengr iOS

**Status:**
- **PASS**: wirklich ausgeführt, erwartetes Verhalten beobachtet
- **FAIL**: ausgeführt, Abweichung beobachtet
- **BLOCKED**: in dieser Umgebung nicht ausführbar
- **NOT TESTED**: bewusst nicht ausgeführt

Screenshots: [`screenshots/`](screenshots/). Bug-IDs: [BUG_REPORT](BUG_REPORT.md).

## Zusammenfassung

| Kategorie | Ausgeführt | PASS | FAIL | BLOCKED | NOT TESTED |
|---|---|---|---|---|---|
| Build / Statik | 3 | 3 | 0 | 0 | 0 |
| Unit-Tests App (47 Einzeltests) | 1 Suite | 1 | 0 | 0 | 0 |
| Backend-Tests (75 Einzeltests) | 1 Suite | 1 | 0 | 0 | 0 |
| Gameplay E2E (UI) | 26 | 19 | 7 | 0 | 0 |
| Screens / Einstellungen (UI) | 12 | 8 | 4 | 0 | 0 |
| Layout / Geräte / Darstellung | 9 | 4 | 5 | 0 | 0 |
| Accessibility | 10 | 0 | 10 | 0 | 0 |
| Performance / Stabilität | 6 | 6 | 0 | 0 | 0 |
| Sicherheit (lokal) | 4 | 0 | 4 | 0 | 0 |
| Nicht ausführbar / nicht getestet | – | – | – | 9 | 8 |
| **Summe** | **72** | **42** | **30** | **9** | **8** |

## 1. Build und automatisierte Suiten

| ID | Test | Status | Beleg |
|---|---|---|---|
| B-01 | Clean Build Debug Simulator | PASS | `logs/01_clean_build.log` |
| B-02 | Build mit `SWIFT_STRICT_CONCURRENCY=complete` | PASS (58 Warnungen) | `logs/02_*` |
| B-03 | Compiler-Warnungen Standard | PASS (12 Warnungen) | `logs/01_build_warnings.txt` |
| U-01 | 47 Unit-Tests `ChallengrTests` | PASS | `logs/03_ios_unit_tests.log` |
| U-02 | 75 Backend-Tests | PASS | `logs/04_backend_tests.log` |

## 2. Gameplay (End-to-End in der App, iPhone 17 Pro)

| ID | Ziel | Status | Beobachtung | Beleg |
|---|---|---|---|---|
| GP01 | Onboarding beim ersten Start (3 Seiten → Karte) | PASS | alle Seiten, „Los geht's“ führt zur Karte | GP01_*.jpg |
| GP02 | Onboarding überspringen, beim 2. Start nicht mehr zeigen | PASS | Wert persistiert | GP02_second_launch.jpg |
| GP03 | Karte zeigt Spieler in der Nähe und Punkte | PASS | Zähler + Pins + Punkte-Chip | GP03_map_nearby.jpg |
| GP04 | Spieler-Popup → Kategorie-Dialog → Zufalls-Challenge | PASS | Kategorien mit Anzahl; Customer (0) deaktiviert | GP04_*.jpg |
| GP05 | Gesendeter Text = empfangener Text | PASS | identisch („Wer hält länger einen Plank …“) | GP05_outgoing_waiting.jpg |
| GP06 | Eigene Anfrage abbrechen | PASS | Gegner erhält `CANCELLED`, Overlay weg | GP06_after_cancel.jpg |
| GP07 | Gegner lehnt ab → Banner | PASS | „Challenge wurde abgelehnt“ | GP07_declined_banner.jpg |
| GP08a | Doppel-Tap auf SENDEN | PASS | genau 1 Anfrage beim Gegner | GP08_*.jpg |
| GP09 | Eingehende Challenge ablehnen | PASS | Popup mit korrektem Text, Gegner erhält `DECLINED` | GP09_incoming_popup.jpg |
| GP10 | Normales Battle: Geschafft → Voting → Sieg → Punkte | PASS | 200 → 230, Chip aktualisiert | GP10_*.jpg |
| GP11 | Aufgeben → Niederlage → Punkte | PASS | 230 → 210 | GP11_lose_screen.jpg |
| GP12 | Unterschiedliche Stimmen → Konflikt | PASS | Niederlage-Screen mit „Konflikt“-Text | GP12_conflict_result.jpg |
| GP13 | Wissen: richtige Antwort gewinnt | PASS | Sieg | GP13_*.jpg |
| **GP14** | Wissen: beide antworten falsch | **FAIL** | nach 20 s kein Ergebnis, keine zweite Antwort möglich | GP14_both_wrong_after_20s.jpg → **BUG-03** |
| GP15 | Sprint: Gegner weiter gelaufen → Niederlage + Messwerte | PASS | 12,5 m gegen 0,0 m angezeigt | GP15_*.jpg |
| GP16 | Eingehende Anfrage läuft nach 60 s ab | PASS | nach 64 s `EXPIRED`, Popup weg | GP16_after_expiry.jpg |
| **GP17** | Anfrage eines Dritten während laufendem Battle | **FAIL** | Aufgeben geht an falsches Battle, UI hängt in „Ergebnis wird berechnet“ | GP17_*.jpg, `logs/06_*` → **BUG-02** |
| GP18 | Hintergrund → zurück, Popup bleibt | PASS | Popup erhalten | GP18_after_background.jpg |
| GP19 | Challenge kommt im Hintergrund an | PASS | Mitteilung „Neue Challenge!“ sichtbar, Popup nach Rückkehr | GP19_*.jpg |
| **FU01a** | Neustart während eigener offener Anfrage: Warte-Zustand | **FAIL** | Overlay verschwunden | FU01_after_relaunch.jpg → **BUG-05** |
| FU01b | Erneut herausfordern → Server lehnt ab → Banner | PASS | Banner „offene Challenge“ | FU01_second_request_banner.jpg |
| **FU01c** | Gegner nimmt alte Anfrage an → App ins Battle | **FAIL** | App bleibt auf der Karte | FU01_opponent_accepts_old_request.jpg → **BUG-05** |
| **FU02a** | Neustart im Battle: Battle-UI wiederhergestellt | **FAIL** | Karte statt Battle | FU02_after_relaunch_in_battle.jpg → **BUG-06** |
| FU02b | Neustart im Battle: Ergebnis kommt trotzdem an | PASS | Sieg-Screen | FU02_result_after_relaunch.jpg |
| **GP14-UX** | Rückmeldung nach falscher Antwort | **FAIL** | keine Rückmeldung, Button wirkt aktiv | GP14_*.jpg → **BUG-20** |
| **GP17-UX** | Überlagerte Overlays | **FAIL** | „Ergebnis wird berechnet“ über fremdem Popup | GP17_after_surrender.jpg → **BUG-02** |

## 3. Screens, Einstellungen, Robustheit

| ID | Ziel | Status | Beobachtung | Beleg |
|---|---|---|---|---|
| SC01a | Shop öffnen, Item kaufen | PASS | 203 → 153 Punkte | SC01_*.jpg |
| SC01b | Zu teure Items | PASS | KAUFEN-Button korrekt deaktiviert | SC01_not_enough_points.jpg |
| RT01 | Schalter „Soundeffekte“ | PASS | 1 → 0 | RT01_sound_toggled_off.jpg |
| SC02a | Logout → Login-Screen | PASS | Login erscheint | SC02_after_logout.jpg |
| **SC02b** | Nach Logout keine Spielnachrichten mehr | **FAIL** | Backend liefert an offene Session von `audit-1` | `logs/09_*` → **BUG-09** |
| RT02a | Profil öffnen | PASS | Punkte, Streak, Statistik, Badges | RT02_profile*.jpg |
| **RT02b** | Freunde-Seite | **FAIL** | „Standort benötigt für Freunde in der Nähe.“, keine Liste | RT02_friends.jpg → **BUG-13** |
| RT02c | Trophy Road | PASS | öffnet, scrollt | RT02_trophy_road.jpg |
| SC04 | Freundschaftsanfrage → Banner + Badge | PASS | Banner + „1“ | SC04_*.jpg |
| SC05 / RT03 | Schnelle Mehrfach-Taps (Zahnrad, Punkte-Chip) | PASS | kein Absturz, maximal 1 Sheet | SC05_*.jpg, RT03_*.jpg |
| **SC06** | Spieler-Popup durch Tippen daneben schließen | **FAIL** | bleibt offen | SC06_popup_after_tap_outside.jpg → **BUG-12** |
| **SC07** | Backend nicht erreichbar | **FAIL** (UX) | kein Absturz, aber keine Fehlermeldung, Punkte „0“, „Noch keine Spieler“; nur der Shop meldet „nicht erreichbar“ | SC07_*.jpg → **BUG-11** |

## 4. Layout, Geräte, Darstellung

| ID | Gerät / Einstellung | Status | Beobachtung | Beleg |
|---|---|---|---|---|
| **LAY-17P** | iPhone 17 Pro, hell, Standard-Schrift | **FAIL** | Battle-Screen läuft rechts über den Rand, Titel überlappt Karte | LAY_iPhone17Pro_3_battle.jpg, GP10_battle_view.jpg → **BUG-08** |
| **LAY-16e** | iPhone 16e (kleinstes verfügbares) | **FAIL** | gleicher Überlauf, Titel abgeschnitten | LAY_iPhone16e_3_battle.jpg → **BUG-08** |
| **LAY-iPad** | iPad Pro 11" | **FAIL** | Battle-Layout nicht angepasst, Name überlappt VS | LAY_iPadPro11_*.jpg → **BUG-16** |
| **LAY-DARK** | iPhone 17 Pro, Dark Mode + größte Schrift | **FAIL** | Titel/Buttons weiß auf weiß, Markenfarben weg; Challenge-Text abgeschnitten | LAY_17Pro-dark-XXXL_*.jpg → **BUG-04**, **BUG-14** |
| **LAY-LAND** | Querformat iPhone | **FAIL** (UX) | nutzbar, aber Pokal-Button mitten zwischen Pins, Layout nicht für Querformat gestaltet | LAY_iPhone17Pro_landscape_*.jpg → **BUG-16** |
| LAY-S1 | Karte, Shop, Niederlage auf iPhone 16e | PASS | lesbar, keine Überlappung | LAY_iPhone16e_1/4/5 |
| LAY-S2 | Karte, Shop auf iPad | PASS | nutzbar | LAY_iPadPro11_1/5 |
| LAY-S3 | Einstellungen Querformat | PASS | Systemliste passt sich an | LAY_*_landscape_settings.jpg |
| LAY-S4 | Eingehendes Popup auf allen Geräten (hell) | PASS | lesbar | LAY_*_2_incoming.jpg |

## 5. Accessibility (automatisierter Audit, `performAccessibilityAudit`)

| ID | Screen | Befunde | Status |
|---|---|---|---|
| A11Y-01 | Login | 12 | FAIL |
| A11Y-02 | Onboarding | 6 | FAIL |
| A11Y-03 | Karte | 29 | FAIL |
| A11Y-04 | Shop | 60 | FAIL |
| A11Y-05 | Einstellungen | 9 | FAIL |
| A11Y-06 | Profil | 30 | FAIL |
| A11Y-07 | Eingehende Challenge | 40 | FAIL |
| A11Y-08 | Battle | 12 | FAIL |
| A11Y-09 | Niederlage | 20 | FAIL |
| A11Y-10 | Profil-Button mit Badge heißt „1“ | – | FAIL (beobachtet im Hierarchie-Dump) |

Summe **218**: Dynamic Type 90 (+3 teilweise), Label nicht lesbar 62, Kontrast ungenügend 34, Kontrast knapp 21, Touch-Fläche zu klein 6, Text abgeschnitten 2. → **BUG-10**

## 6. Performance und Stabilität

| ID | Messung | Status | Ergebnis |
|---|---|---|---|
| PERF-01 | App-Start (5×, bis erster reaktionsfähiger Frame) | PASS | Ø 2,56 s (1,72–3,52 s), Simulator Debug |
| PERF-02 | Speicher/CPU bei Sheet-Wechseln (5×3 Zyklen) | PASS | ≈ 121 MB, +0,75 MB/Durchgang, CPU 3,2 s/Durchgang |
| PERF-03 | Speicher über 6 Battle-Runden | PASS | 118,5 → 120,2 MB, Peak 128,9 MB |
| PERF-04 | `leaks` nach 5 Anfrage-Zyklen | PASS | **0 Leaks**, Footprint 104 MB |
| PERF-05 | Instruments Time Profiler, 15 s Karte | PASS | 16 CPU-Samples, **0 Hang-Risiken** |
| STAB-01 | Absturz in irgendeinem UI-Test | PASS | **kein Absturz** in 50 UI-Testläufen |

## 7. Sicherheit (nur lokales Audit-Backend)

| ID | Prüfung | Status | Beleg |
|---|---|---|---|
| SEC-01 | Spielerliste mit Positionen ohne Token | FAIL | `logs/05_*` → BUG-01 |
| SEC-02 | Fremden Spieler umbenennen ohne Token | FAIL | `logs/05_*` → BUG-01 |
| SEC-03 | Richtige Wissens-Antworten ohne Token abrufbar | FAIL | `logs/05_*` → BUG-01 |
| SEC-04 | Admin-Übersicht ohne Token | FAIL (lokal; Produktiv statisch: `@PermitAll`) | `logs/05_*` → BUG-01 |

## 8. BLOCKED und NOT TESTED

| ID | Bereich | Status | Grund |
|---|---|---|---|
| X-01 | Echter Keycloak-Login / Logout / SSO-Verhalten | BLOCKED | kein Testkonto, Produktivsystem nicht verändern |
| X-02 | Liegestütze (ARKit Face Tracking) | BLOCKED | TrueDepth-Kamera im Simulator nicht verfügbar |
| X-03 | Kamera-Challenge, QR-Scanner | BLOCKED | keine Kamera im Simulator |
| X-04 | Kompass-Challenge | BLOCKED | kein Kompass im Simulator |
| X-05 | Echtes Gerät (Performance, Akku, GPS-Genauigkeit) | BLOCKED | kein Gerät verfügbar |
| X-06 | iOS 17.6 – 25 | BLOCKED | nur iOS-26-Laufzeit installiert |
| X-07 | VoiceOver manuell | BLOCKED | nur automatisierter Audit möglich |
| X-08 | Remote Push | BLOCKED | nicht implementiert |
| X-09 | Hörbare Sounds / Haptik | BLOCKED | im Test nicht messbar (nur Dateien geprüft) |
| N-01 | Schrei-, Shake-, Check-In-Challenge | NOT TESTED | Sensorwerte im Simulator nicht sinnvoll steuerbar in der Zeit |
| N-02 | Charakter-Editor | NOT TESTED | Zeitpriorität |
| N-03 | Geschenke senden/öffnen | NOT TESTED | Zeitpriorität |
| N-04 | AirDrop-Einladung | NOT TESTED | benötigt zweites Gerät |
| N-05 | Challenge-Katalog aus Trophy Road | NOT TESTED | Zeitpriorität |
| N-06 | Admin-Dashboard (Web) | NOT TESTED | außerhalb des Swift-Fokus |
| N-07 | Akzeptieren gleichzeitig mit Abbruch (Race, CA-04) | NOT TESTED | Timing nicht reproduzierbar steuerbar |
| N-08 | Langzeit (> 30 min) | NOT TESTED | Zeitrahmen |
