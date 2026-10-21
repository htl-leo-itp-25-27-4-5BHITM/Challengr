# Spezifikation: Keycloak-Integration (Identity & Access Management)

## 1. Einführung
Um die Sicherheit, Skalierbarkeit und Nutzerverwaltung der **Challengr**-Plattform zu gewährleisten, wurde **Keycloak** als zentraler Identity- und Access-Management-Provider (IAM) integriert. Dieser übernimmt die Authentifizierung der iOS-App und autorisiert die Zugriffe auf das Quarkus-Backend.

## 2. Architektur & Workflow
Die Authentifizierung basiert auf **OpenID Connect (OIDC)** und dem **OAuth 2.0 Authorization Code Flow mit PKCE** (Proof Key for Code Exchange) für die mobile Anwendung.

### Ablauf der Authentifizierung:
1. **Login:** Der Nutzer öffnet die iOS App und wird auf den In-App-Browser (.sheet) zum Keycloak-Loginscreen weitergeleitet.
2. **Authentifizierung:** Der Nutzer gibt seine Credentials ein (oder registriert sich). Keycloak validiert diese.
3. **Token-Ausstellung:** Die App erhält nach erfolgreichem Login ein `Access Token` (JWT), ein `Refresh Token` und ein `ID Token`.
4. **Backend-Autorisierung:** Bei jeder Anfrage an das Quarkus-Backend wird das Access-Token im `Authorization: Bearer <Token>` Header mitgesendet.
5. **Validierung (Backend):** Das Quarkus-Backend verifiziert die Signatur und Gültigkeit des Tokens lokal (bzw. über Keycloak) und gestattet den Zugriff auf die Endpunkte.

## 3. Konfiguration in Keycloak
Für das Projekt wurde ein eigener Realm sowie spezifische Clients für die verschiedenen Komponenten angelegt.

### 3.1. Realm
* **Name:** `challengr`
* **Zweck:** Isolation der Nutzer- und Client-Daten für dieses spezifische Projekt.

### 3.2. Clients
| Client-ID | Client-Typ | Authentifizierungs-Flow | Zweck |
| :--- | :--- | :--- | :--- |
| `challengr-ios` | Public | Auth Code Flow mit PKCE | Authentifizierung der Nutzer in der iOS-SwiftUI-App. Erlaubt keine Client-Secrets auf dem mobilen Endgerät. |
| `challengr-backend` | Confidential | Service Accounts (Client Credentials) / Bearer-Only | Validierung der Tokens im Quarkus-Backend. Das Secret ist sicher im Kubernetes-Cluster hinterlegt. |

### 3.3. Infrastruktur & Persistenz
* Über Umstellung von In-Memory (H2) auf eine **PostgreSQL**-Datenbank innerhalb des Kubernetes-Clusters werden User-Daten persistent gespeichert.
* Der Keycloak-Server wird über einen **Nginx Ingress** mit HTTPS (Proxy-Modus: `edge`) nach außen exponiert (`/auth`).

## 4. Komponenten-Integration

### 4.1. iOS App (Swift)
* **KeycloakAuthService:** Managed den stateful OIDC OAuth2v2 Login via `AppAuth` / Web-Login.
* **Payload-Decoding:** Aus dem JWT werden die ID (`sub`) und der Name (`preferred_username` / `given_name`) extrahiert.
* **Dynamic Player Creation:** Nach dem Login wird der Endpunkt `/api/players` genutzt, um sicherzustellen, dass der Nutzer in der Gameplay-Datenbank mit einer spezifischen `playerId` registriert ist (`ensurePlayerId()`).

### 4.2. Backend (Quarkus / Java)
* **OIDC Extension:** Verwendet `quarkus-oidc` zur Validierung der Bearer-Tokens.
* **Application.properties:** 
  * `quarkus.oidc.auth-server-url`: URL zum Keycloak `challengr`-Realm.
  * `quarkus.oidc.client-id`: `challengr-backend`
  * Verknüpfung via Kubernetes-Secrets (`KEYCLOAK_CLIENT_SECRET`).
* Das Backend erstellt bei Bedarf (via REST-API) Gameplay-Identitäten und verknüpft die Keycloak-User-Sub-ID (z. B. UUID) mit den In-Game-Punkten und Locations.

## 5. Zukünftige Erweiterungsmöglichkeiten
* **Rollenbasiertes Access Management (RBAC):** Zuordnung von Rollen (z. B. `admin`, `player`) über Keycloak, um administrative Endpunkte in Quarkus abzusichern.
* **Web-App Integration:** Erweiterung des Login-Flows für die interaktive Map-Webanwendung.
* **Social Login:** Einbinden von Apple Sign-In oder Google Login als Identity Provider direkt in Keycloak (ohne Code-Änderungen am Backend).