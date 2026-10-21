# Challengr – Command Cheatsheet

Kurze Sammlung der wichtigsten Befehle zum Copy/Paste.

## Deploy (LeoCloud)

### Dashboard deployen
```bash
./scripts/deploy-cloud.sh dashboard
kubectl -n student-it220257 rollout restart deployment/challengr-dashboard
```

### Backend deployen
```bash
./scripts/deploy-cloud.sh backend
kubectl -n student-it220257 rollout restart deployment/challengr-backend
```

### Backend + Dashboard deployen
```bash
./scripts/deploy-cloud.sh both
```

### Keycloak (Theme/Config) aktualisieren
```bash
kubectl apply -f k8s/keycloak-theme-configmap.yaml
kubectl apply -f k8s/keycloak.yaml
kubectl -n student-it220257 rollout restart deployment/challengr-keycloak
```

## Kubernetes Basics

### Status prüfen
```bash
kubectl -n student-it220257 get pods
kubectl -n student-it220257 get svc
kubectl -n student-it220257 get ingress
```

### Logs ansehen
```bash
kubectl -n student-it220257 logs deploy/challengr-dashboard --tail=200
kubectl -n student-it220257 logs deploy/challengr-backend --tail=200
kubectl -n student-it220257 logs deploy/challengr-keycloak --tail=200
```

### Services lokal forwarden
```bash
kubectl -n student-it220257 port-forward svc/challengr-backend-service 8080:8080
kubectl -n student-it220257 port-forward svc/challengr-keycloak-service 9090:8080
```

## Lokale Entwicklung

### Dashboard lokal starten
```bash
cd Dashboard
npm install
npm run start
```

### Backend lokal starten
```bash
cd Backend/challengrbackend
./mvnw quarkus:dev
```

### Lokales Dev-Setup (Docker + DB-Tunnel)
```bash
./scripts/dev-cloud.sh
```

## Docker Compose (lokaler Stack)
```bash
docker compose --profile local-stack up --build
```
