# Challengr

Challengr ist eine Plattform für spontane Real-Life-Challenges.
Nutzer können sich in ihrer Nähe treffen, kleine Aufgaben gegeneinander absolvieren, Punkte sammeln und in Ranglisten aufsteigen.
Die App verbindet Real-Life-Interaktion, Gamification und Standortfunktionen.

[Figma-Design für Challengr](https://www.figma.com/design/OQ6QYvTq1UIQZRkCFZPHSL/Challengr?t=awcb6RPzgswE0VKY-1)

---

## Projektübersicht

- Zielgruppe: Jugendliche und junge Erwachsene, Gamer, Fitness- und Outdoor-affine Menschen, Gruppen von Freunden
- Plattformen: iOS-App (Swift) und Webanwendung (HTML)
- Backend: Quarkus (Java)
- Funktionen (geplant):

  - Nutzerregistrierung / Login (zukünftig)
  - Standortbasierte Challenges im Umkreis von z.B. 50 m
  - Erstellung und Annahme von Challenges
  - Punktesystem mit Münzen, Trophäen und Ranglisten
  - Shop-System für Items und Skins
  - Push-Notifications für neue Challenge-Anfragen

---

## Sprint (Sprint 1 – Start: 15.10.2025)

Ziele:

- Kategorien und Challenges anzeigen
- Gemeinsames Backend für Web und Swift
- Markdown-Projektantrag auf GitHub

---

## Sprint (Sprint 2 – Start: 5.11.2025)

Ziele:

- Kartensystem in Applikationen einbinden
- Standortfindung

---

## Sprint (Sprint 3 – Start: 19.11.2025)

Ziele:

* Zweiten Spieler auf der Karte anzeigen
* Standortdaten über Datenbank austauschen (PostgreSQL)
* WebSockets für Echtzeit-Positionsupdates nutzen (WebApp & Swift)
* Docker-Setup vorbereiten (c.aberger-Webimage - Compose)
* Datenbankschema + import.sql im Backend (Quarkus) aufsetzen
* Vorbereitung & Evaluierung WebSockets unter Swift

---

## Sprint (Sprint 4 – Start: 3.12.2025)

Ziele:

* Implementieren einer Funktion, mit der ein Spieler eine Challenge an einem fremden Spieler vorschlagen kann
* Erstellen und verwalten eines Radius-Checks, um zu bestimmen, welche Spieler als mögliche Zielspieler verfügbar sind
* Implementieren einer Meldung/Benachrichtigung, die dem herausfordernden Spieler die Device-ID des herausgefordertem Spieler anzeigt
* Entwicklung eines Dialog-Fensters, das die Herausforderung klar visualisiert
* Integrieren einer Vibrationsfunktion, wenn ein Spieler in den eigenen Radius gelangt

---

## Sprint (Sprint 5 – Start: 17.12.2025)

Ziele:

* Anzeige der zugewiesenen Challenge für herausgeforderte Spieler:innen
* Visualisierung des Radius in der Map-Ansicht
* Einführung von WebSockets für Echtzeit-Updates

---

## Sprint (Sprint 6 – Start: 14.01.2026)

Ziele:

* Verbesserung des Stylings
* Entwicklung eines vollständigen Dialoges für eine Challenge
* Evaluierung eines JS‑Bundlers (Vite mit Proxy‑Setup und fixem Entwicklungsport) - Alternativ Webpack

---

## Sprint (Sprint 7 – Start: 28.01.2026)

Ziele:

* Einbindung eines Punktesystems
* Speicherung der Punkte im Backend
* Implementierung der Dialog Logik in der WebApp

---

## Sprint (Sprint 8 – Start: 11.02.2026)

Ziele:

* Finale Entwicklung eines Punktesystems
* Speicherung der Punkte im Backend
* Dynamisches Laden des Trophy Pfads
* Einheitliches Styling

---

## Sprint (Sprint 9 – Start: 04.03.2026)

Ziele:

* Warnung für 3te Wiederholung einer Uneinigkeit
* Dummy Profile implementieren
* Triviale Statistiken einbauen/anzeigen
* Challenge Überarbeitung
* Streaksystem

---

## Sprint (Sprint 10 – Start: 18.03.2026)

Ziele:

* Verbindung von Projekt mit LeoCloud

---



## Sprint (Sprint 11 – Start: 08.04.2026)

Ziele:

* Teilweise Einbindung von Keycloack (Aufteilung auf 2 Sprints)
* Präsentation über Keycloack inklusive Erklärung von Einbindung in Projekt

---

## Lokaler Schnellstart (WebApp + Cloud Backend)

Im Projekt-Root reicht jetzt **ein Befehl**:

```bash
./scripts/dev-cloud.sh
```

Der Befehl macht automatisch:

- lokale WebApp auf `http://localhost:5173` starten
- Proxy auf Cloud-Backend (`https://it220257.cloud.htl-leonding.ac.at`) setzen
- DB-Tunnel für IntelliJ auf `localhost:15432` starten

IntelliJ-DB-Verbindung:

- Host: `localhost`
- Port: `15432`
- Database/User/Passwort: `postgres/postgres/postgres`

DB-Tunnel stoppen:

```bash
./scripts/db-tunnel-stop.sh
```

Optional: kompletten lokalen Stack (Postgres + Backend + WebApp) starten:

```bash
docker compose --profile local-stack up --build
```

---

## LeoCloud Deployment

Für LeoCloud gibt es ein separates Setup im Ordner `k8s/`.

Die genaue Anleitung findest du in:

- `k8s/README.md`

Kurz gesagt:

1. Backend-Image bauen und pushen
2. WebApp-Image bauen und pushen
3. Secret anlegen
4. Kubernetes-Manifeste aus `k8s/` deployen

Ziel-URL:

- `https://it220257.cloud.htl-leonding.ac.at`

### Einfacher Deploy-Befehl (für alle im Team)

Im Projekt-Root:

```bash
./scripts/deploy-cloud.sh backend
./scripts/deploy-cloud.sh webapp
./scripts/deploy-cloud.sh both
```

Damit werden Images gebaut/zu GHCR gepusht und die passenden Kubernetes Deployments automatisch neu gestartet.
