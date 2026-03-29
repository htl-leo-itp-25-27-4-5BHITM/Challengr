# Challengr auf LeoCloud deployen

Namespace: `student-it220257`
Ziel-URL: `https://it220257.cloud.htl-leonding.ac.at`

## Überblick

Für LeoCloud werden **drei Teile** deployed:

1. `challengr-postgres` – PostgreSQL
2. `challengr-backend` – Quarkus Backend
3. `challengr-webapp` – statische WebApp über nginx

Die lokale `docker-compose.yml` bleibt für Development bestehen. Für LeoCloud werden die Dateien im Ordner `k8s/` verwendet.

---

## 1. Voraussetzungen

- Docker läuft lokal
- LeoCloud CLI / kubeconfig funktioniert
- du bist im richtigen Namespace oder kannst darauf deployen
- Schreibrechte auf eine Container Registry (empfohlen: GHCR)

---

## 2. Backend-Image bauen und pushen

```bash
cd Backend/challengrbackend
./mvnw clean package -DskipTests

docker build -f src/main/docker/Dockerfile.txt -t ghcr.io/htl-leo-itp-25-27-4-5bhitm/challengr-backend:latest .
docker push ghcr.io/htl-leo-itp-25-27-4-5bhitm/challengr-backend:latest
```

---

## 3. WebApp-Image bauen und pushen

```bash
cd WebApp

docker build -t ghcr.io/htl-leo-itp-25-27-4-5bhitm/challengr-webapp:latest .
docker push ghcr.io/htl-leo-itp-25-27-4-5bhitm/challengr-webapp:latest
```

---

## 4. In LeoCloud einloggen

Falls verfügbar:

```bash
leocloud dashboard
```

Dann prüfen, ob du Zugriff auf den Namespace `student-it220257` hast.

Optional mit `kubectl`:

```bash
kubectl config current-context
kubectl get ns
kubectl config set-context --current --namespace=student-it220257
```

---

## 5. Secret anlegen

Nutze `k8s/secret-example.yaml` als Vorlage oder lege es direkt mit `kubectl` an.

### Variante A – aus Datei

```bash
kubectl apply -f k8s/secret-example.yaml
```

### Variante B – direkt per CLI

```bash
kubectl -n student-it220257 create secret generic challengr-secrets \
  --from-literal=POSTGRES_DB=postgres \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=postgres
```

Wenn das Secret schon existiert, zuerst löschen oder `apply` mit YAML verwenden.

---

## 6. Deployen

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/webapp.yaml
kubectl apply -f k8s/ingress.yaml
```

Hinweis: Falls der Namespace schon existiert, ist `namespace.yaml` unkritisch.

---

## 7. Status prüfen

```bash
kubectl -n student-it220257 get pods
kubectl -n student-it220257 get svc
kubectl -n student-it220257 get ingress
```

Logs prüfen:

```bash
kubectl -n student-it220257 logs deploy/challengr-backend
kubectl -n student-it220257 logs deploy/challengr-webapp
kubectl -n student-it220257 logs deploy/challengr-postgres
```

---

## 8. Testen

Nach erfolgreichem Deployment:

- WebApp: `https://it220257.cloud.htl-leonding.ac.at`
- Backend via Proxy durch nginx: `https://it220257.cloud.htl-leonding.ac.at/api/challenges`

Wenn du das Backend direkt intern prüfen willst:

```bash
kubectl -n student-it220257 port-forward svc/challengr-backend-service 8080:8080
```

Dann lokal:

- `http://localhost:8080`
- `http://localhost:8080/api/challenges`
- `http://localhost:8080/q/health`

---

## 9. Updates deployen

Nach Codeänderungen:

1. Images neu bauen
2. Images neu pushen
3. Deployments neu starten

```bash
kubectl -n student-it220257 rollout restart deployment/challengr-backend
kubectl -n student-it220257 rollout restart deployment/challengr-webapp
```

---

## 10. Häufige Probleme

### WebApp startet, aber API geht nicht
- Prüfen, ob `challengr-backend-service` läuft
- Backend-Logs prüfen
- Ingress prüfen

### Backend startet, aber DB-Verbindung fehlt
- Secret prüfen
- `challengr-postgres` Pod prüfen
- Service `challengr-postgres-service` prüfen

### WebSocket geht nicht
- `/ws` wird in `WebApp/docker/nginx.conf` zum Backend durchgereicht
- Backend muss unter `challengr-backend-service:8080` erreichbar sein
- Ingress/Proxy muss Upgrade-Header durchlassen

---

## Dateien

- `WebApp/Dockerfile` – Production-WebApp mit nginx
- `WebApp/docker/nginx.conf` – Proxy für `/api` und `/ws`
- `k8s/postgres.yaml` – PostgreSQL + PVC + Service
- `k8s/backend.yaml` – Quarkus Deployment + Service
- `k8s/webapp.yaml` – WebApp Deployment + Service
- `k8s/ingress.yaml` – öffentliche Route für LeoCloud
- `k8s/secret-example.yaml` – Beispiel-Secret
