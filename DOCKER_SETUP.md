# Challengr Docker Setup

## Schnellstart (ein Befehl)

```bash
./scripts/dev-cloud.sh
```

Was der Befehl automatisch startet:

- lokale WebApp (`http://localhost:5173`)
- Proxy auf Cloud-Backend + Cloud-WebSocket
- stabilen DB-Tunnel nach Kubernetes auf `localhost:15432`

### DB-Verbindung in IntelliJ/DataGrip

- Host: `localhost`
- Port: `15432`
- Database: `postgres`
- User: `postgres`
- Password: `postgres`

Tunnel stoppen:

```bash
./scripts/db-tunnel-stop.sh
```

---

## Optional: kompletter lokaler Stack

```bash
docker compose --profile local-stack up --build
```

Dann laufen PostgreSQL + Backend + WebApp lokal.

---

## Lokal entwickeln (ohne Docker)

### Backend (Quarkus)
```bash
cd Backend/challengrbackend

# Dev-Mode mit auto-reload
./mvnw quarkus:dev

# Portiert auf http://localhost:8080
```

### WebApp (Vite)
```bash
cd WebApp

# Dependencies installieren
npm install

# Dev-Server starten
npm run dev

# Portiert auf http://localhost:5173
```

**Voraussetzung**: PostgreSQL muss auf `localhost:5432` laufen

---

## Für die Cloud

### Environment Variables setzen:
```bash
QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://cloud-postgres:5432/postgres
QUARKUS_DATASOURCE_USERNAME=prod_user
QUARKUS_DATASOURCE_PASSWORD=strong_password_here
QUARKUS_PROFILE=prod
```

### Docker Image bauen:
```bash
cd Backend/challengrbackend
./mvnw clean package -DskipTests
docker build -f src/main/docker/Dockerfile.txt -t challengr-backend:latest .
```

### In die Cloud pushen:
```bash
# Registry anmelden (z.B. Docker Hub, AWS ECR, etc.)
docker tag challengr-backend:latest your-registry/challengr-backend:latest
docker push your-registry/challengr-backend:latest
```

---

## Struktur

```
Challengr/
├── docker-compose.yml          # Development Setup
├── .env.local                  # Environment Variables (lokal)
├── Backend/
│   └── challengrbackend/       # Quarkus Backend
│       ├── src/main/
│       │   └── resources/
│       │       ├── application.properties        # Base Config
│       │       └── application-prod.properties   # Prod Config
│       └── src/main/docker/
│           └── Dockerfile.txt                    # Docker Build
└── WebApp/                     # Vite WebApp
```

---

## Tipps für Production

1. **Secrets nicht in Code**: Verwende `.env` Dateien oder Secret Manager
2. **Health Checks**: Backend Health Check auf http://localhost:8080/q/health
3. **Datensicherung**: PostgreSQL Volume regelmäßig backupen
4. **Logging**: Logs monitoren und zentral sammeln
