# Claude-Agenten im Challengr-Projekt

Stand: 6. November 2026

Eigene Agenten für Claude Code liegen in `.claude/agents/` (eine Markdown-Datei pro Agent). Sie laufen auf
günstigeren Modellen (Haiku, Sonnet) und übernehmen wiederkehrende, klar abgegrenzte Aufgaben. Opus behält die
schweren Sachen: neue Features, Fehlersuche, Design-Entscheidungen und alles, was nach außen geht.

## Übersicht

| Agent | Modell | Schreibt? | Wofür |
|---|---|---|---|
| `test-laeufer` | Haiku | nein | Tests ausführen, nur das Ergebnis melden |
| `doku-pfleger` | Sonnet | nur `docs/` + Commit | Projektstand, Tester-Text, Doku-Commit |
| `sim-vorbereiter` | Haiku | nur Test-Harness | Test-Backend, Testdaten, zwei Simulatoren |
| `ui-pruefer` | Sonnet | nur UI-Tests im Harness | Bildschirme per Screenshot prüfen |
| `live-check` | Haiku | nein | Kontrolle nach dem Deploy |
| `feedback-sichter` | Sonnet | nein | Tester-Feedback mit Code und Commits abgleichen |
| `figuren-pipeline` | Sonnet | ja (App, Backend, Assets) | Figuren-Entwurf spielbar machen |

**Haiku** nehmen wir für reines Abarbeiten mit eindeutigem Ergebnis: Befehle ausführen, Ausgaben lesen,
„läuft / läuft nicht“. **Sonnet** nehmen wir, wo es Urteil oder gute Texte braucht: Screenshots beurteilen,
Feedback einordnen, Deutsch schreiben, mehrere Dateien sauber anpassen.

## Die Agenten im Einzelnen

### `test-laeufer` (Haiku)
- **Wann:** immer, wenn Tests laufen sollen, Backend (Maven, H2) oder App (xcodebuild), ganz oder einzelne Klassen.
- **Ergebnis:** `X grün, Y rot`, pro Fehler Testname, `Datei:Zeile`, erwartet/bekommen.
- **Darf:** Befehle ausführen und lesen. Behebt keine Fehler.
- **Warum es spart:** Die Testlogs sind oft tausend Zeilen lang und landen so nicht im Opus-Kontext.

### `doku-pfleger` (Sonnet)
- **Wann:** nach einem fertigen Feature, Deploy oder Build.
- **Im Auftrag mitgeben:** Commits, Build-Nummer, Deploy-Zeit, Backup-Datei, offene Punkte.
- **Macht:** trägt in `docs/PROJEKT_STAND.md` an den richtigen Stellen ein (Abschnitte 3, 4, 5, 7, 8), schreibt
  den TestFlight-Tester-Text (höchstens 4000 Zeichen) und macht den Doku-Commit. Pusht nie.
- **Regeln:** keine Passwörter oder Schlüssel in der Doku, die Schule nicht nennen, nichts erfinden.

### `sim-vorbereiter` (Haiku)
- **Wann:** „mach mir zwei Sims zum Testen“.
- **Macht:** führt die Skripte im Test-Harness aus (`~/Developer/ChallengrProjekt/TestHarness`):
  1. `./backend_neu.sh`: Backend aus dem Repo, Harness-Patch, Start. Leert die Datenbank.
  2. `./seed.sh` (`--crowd` für 10 Statisten): Basti und Mia mit Freundschaft, Coins, Stickern und einem Geschenk
  3. `./sims_starten.sh` (`--build` nach Swift-Änderungen): Basti in „Challengr Tests“, Mia in „Challengr Demo B“
- **Danach:** Der Nutzer tippt die Mitteilungs-Abfrage weg und testet selbst.

### `ui-pruefer` (Sonnet)
- **Wann:** wenn man wissen will, wie ein Bildschirm aussieht, statt selbst Screenshots zu öffnen.
- **Im Auftrag mitgeben:** welche Bildschirme oder Abläufe und worauf zu achten ist.
- **Macht:** schreibt einen kleinen UI-Test im Harness (`ChallengrUITests/<Name>Shots.swift`), macht Screenshots,
  schaut sie selbst an und meldet pro Bild ✅ oder das Problem, dazu die 1–3 Bilder, die man sich ansehen sollte.
- **Darf:** keinen App-Code ändern.
- **Warum es spart:** Jedes Bild kostet im Opus-Kontext viel. Bei einem Feature waren es schnell 20 Stück.

### `live-check` (Haiku)
- **Wann:** direkt nach `./scripts/deploy-cloud.sh`.
- **Im Auftrag mitgeben:** was neu ist (Spalten, Tabellen, Endpunkte, Umgebungsvariablen).
- **Prüft:** Pods, Logs, Datenbank nur mit `SELECT`, Endpunkte ohne Login (401 = gibt es), ob Secrets gesetzt
  sind (nur ob und wie lang, nie den Wert).
- **Darf:** nichts ändern, kein `kubectl apply/create/delete`, kein Schreiben in die Datenbank.

### `feedback-sichter` (Sonnet)
- **Wann:** wenn neues Tester-Feedback da ist.
- **Im Auftrag mitgeben:** den Pfad zum Export aus dem Dashboard (PDF oder Markdown-ZIP).
- **Macht:** liest Text und Screenshots (PDF über `TestHarness/tools/pdf_seiten.swift`) und gleicht mit Commits,
  Code und Projektstand ab. Ergebnis ist eine Tabelle erledigt, teilweise, offen mit Beleg und Vorschlag, dazu
  welche Einträge man im Dashboard abhaken kann.
- **Darf:** nichts ändern.

### `figuren-pipeline` (Sonnet)
- **Wann:** wenn eine Entwurfs-Figur spielbar werden soll (Kira, Riot, Valka oder die älteren Vorlagen Vex,
  Blaze, Nova, Raven).
- **Im Auftrag mitgeben:** Name, Freischalt-Regel (z. B. Event-ID oder Trophäen-Grenze), Farbe.
- **Macht:** Export aus `Character3D/pipeline/char/preview/`, SceneKit-Modell, Karten-Animation (16 Bilder),
  Bilder und Asset-Katalog, `GameCharacter`, Backend-`CharacterCatalog`, Tests mit Figurenlisten, dann Build
  und Test. Vorbild ist Frost (`0b21597`).
- **Darf:** App- und Backend-Code ändern, aber nicht committen. Opus prüft und committet.

## Was bewusst kein Agent ist

- **Codesuche:** dafür gibt es den eingebauten Agenten `Explore`.
- **Code-Review:** dafür gibt es den Befehl `/code-review`.
- **Deploy, Push, Merge, TestFlight-Upload, Secrets:** Das geht nach außen und braucht jedes Mal das OK des
  Nutzers. Es bleibt bei Opus. Secrets legt der Nutzer selbst an.
- **Kleinkram** (eine Zeile ändern, eine Datei lesen): Ein Agent startet ohne Vorwissen. Das Briefing kostet
  dann mehr, als es spart.

## Gut zu wissen

- **Neue oder geänderte Agenten** kennt Claude Code erst in einer **neuen Sitzung**.
- **Bash lässt sich nicht auf „nur lesen“ beschränken.** Bei `test-laeufer`, `live-check` und `feedback-sichter`
  steht „ändert nichts“ in der Anleitung. Zusätzlich gelten die Rechte-Regeln aus `.claude/settings.json` und die
  Auto-Prüfung von Claude Code auch für Agenten.
- **Aufruf:** Man muss nichts tun, Opus gibt passende Aufgaben selbst ab. Man kann es aber ausdrücklich sagen,
  z. B. „lass den test-laeufer das Backend testen“.
- **Ändern:** Die Dateien in `.claude/agents/` sind normales Markdown mit einem Kopf (`name`, `description`,
  `model`, `tools`). Wann ein Agent genommen wird, entscheidet die `description`.
