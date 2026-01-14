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
