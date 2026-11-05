<p align="center">
  <img src="Swift/Challengr/Challengr/Assets.xcassets/AppIcon.appiconset/AppIcon-light.png" width="120" alt="Challengr App-Icon">
</p>

<h1 align="center">Challengr</h1>

<p align="center">
  Ortsbasiertes Multiplayer-Spiel fürs iPhone – Spieler in der Nähe finden, herausfordern, Trophäen sammeln.
</p>

<p align="center">
  <a href="https://github.com/htl-leo-itp-25-27-4-5BHITM/Challengr/actions/workflows/ci.yaml"><img src="https://github.com/htl-leo-itp-25-27-4-5BHITM/Challengr/actions/workflows/ci.yaml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/iOS-SwiftUI-orange?logo=swift" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Backend-Quarkus%20·%20Java%2025-4695EB?logo=quarkus" alt="Quarkus">
  <img src="https://img.shields.io/badge/Dashboard-Angular%2021-DD0031?logo=angular" alt="Angular">
  <img src="https://img.shields.io/badge/Status-TestFlight%20Beta-yellow" alt="Status">
</p>

---

## Über das Spiel

Spieler sehen andere Spieler in ihrer Umgebung auf einer 3D-Karte und fordern sie direkt heraus.

- **Liga** – Kämpfe um Trophäen in zwei Spielarten:
  - **Quiz-Show**: vier Wissensfragen à 15 Sekunden in einem animierten 3D-Fernsehstudio.
  - **Real-Life-Challenge**: Aufgaben, die das iPhone misst – Sprint, Lautstärke, Kompass, Schütteln, Liegestütze, Check-in.
- **Friendly** – Kategorie und Challenge frei wählbar, ohne Einsatz.
- **Trophy Road** mit Rängen, freischaltbaren 3D-Figuren, Tagesaufgaben und zeitlich begrenzten Events.
- **Freunde, Rangliste, Emotes** und Check-in-Orte aus OpenStreetMap (Parks, Museen, Brunnen, Plätze …).
- **Sicherheit**: Login-Pflicht, gerundete Standorte, Unsichtbar-Modus, Melden & Blockieren, Konto löschen.

## Architektur

```text
iOS-App (SwiftUI) ──REST / WebSocket──▶  Backend (Quarkus)  ──▶  PostgreSQL
        │                                     │
        └────────── OIDC (PKCE) ──────▶  Keycloak  ◀── Admin-Dashboard (Angular SSR)
```

| Bereich | Ordner | Technik |
|---|---|---|
| iOS-App | [`Swift/`](Swift/) | SwiftUI, MapKit, SceneKit (3D-Figuren), Core Motion |
| Backend | [`Backend/challengrbackend/`](Backend/challengrbackend/) | Quarkus, Java 25, REST + WebSocket, Hibernate Panache, PostgreSQL, OIDC |
| Admin-Dashboard | [`Dashboard/`](Dashboard/) | Angular 21 mit SSR, Keycloak-Login, Analysen, TestFlight-Feedback |
| Web-Client (Test) | [`WebApp/`](WebApp/) | Vite – nur für Tests, im Betrieb abgeschaltet |
| Deployment | [`k8s/`](k8s/), [`scripts/`](scripts/) | Kubernetes, Container-Images auf GHCR |
| Design & Sounds | [`Design/`](Design/) | Konzepte, Assets, Sound-Effekte |
| Dokumentation | [`docs/`](docs/) | Projektstand, Audits, Sprints, Spezifikationen |

## Schnellstart

**Voraussetzungen:** Xcode 26, JDK 25, Node 22, Docker

```bash
# Kompletter lokaler Stack (Postgres + Backend + Dashboard)
docker compose --profile local-stack up --build

# Lokales Dashboard gegen das Cloud-Backend (inkl. DB-Tunnel auf localhost:15432)
./scripts/dev-cloud.sh

# Backend im Dev-Modus mit Live-Reload
cd Backend/challengrbackend && ./mvnw quarkus:dev
```

Die iOS-App wird über `Swift/Challengr/Challengr.xcodeproj` in Xcode gestartet.
Umgebungsvariablen: Vorlage in [`.env.example`](.env.example).

## Tests

```bash
./scripts/test-all.sh            # Backend + iOS
./scripts/test-all.sh backend    # nur Backend
./scripts/test-all.sh ios        # nur iOS (Simulator)
```

Backend-Tests und Dashboard-Build laufen bei jedem Push automatisch über [GitHub Actions](.github/workflows/ci.yaml).

## Deployment

```bash
./scripts/deploy-cloud.sh backend     # oder: dashboard | both
./scripts/upload-testflight.sh        # iOS-Build zu TestFlight
```

Die Skripte bauen die Images, pushen sie zu GHCR und starten die Kubernetes-Deployments neu.
Details zu Manifesten und Secrets: [`k8s/README.md`](k8s/README.md).

## Dokumentation

- [Projektstand & offene Punkte](docs/PROJEKT_STAND.md)
- [Audit-Berichte (Sicherheit, Performance, UX)](docs/audit/README.md)
- [Sprint-Übersicht](docs/projekt/Sprints/README.md)
- [Projektantrag](docs/projekt/ProjectProposal.md) · [Fachspezifikation](docs/projekt/FSD.md) · [Ranglistensystem](docs/projekt/RankingSystem.md)
- [Docker-Setup](docs/DOCKER_SETUP.md)
- [Figma-Design](https://www.figma.com/design/OQ6QYvTq1UIQZRkCFZPHSL/Challengr?t=awcb6RPzgswE0VKY-1)

## Team

- Sebastian Lehner
- Dominik Binder
- Julian Richter
