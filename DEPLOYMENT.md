## Deployment to LeoCloud (HTL Leonding)

Ziel: Das Projekt so bereitstellen, dass es unter
`https://it220257.cloud.htl-leonding.ac.at/` erreichbar ist.

Kurze Übersicht
- Backend: Quarkus-App (port 8080)
- Frontend: Vite-built statische Seite (served via nginx, port 80)
- Datenbank: optional PostgreSQL (mit PVC)

Struktur der erstellten Dateien
- `Backend/challengrbackend/Dockerfile` — Dockerfile für das Java/Quarkus-Backend
- `WebApp/Dockerfile` — Dockerfile für das Vite-Frontend (build -> nginx)
- `k8s/backend.yaml` — Deployment + Service (ClusterIP) für Backend
- `k8s/frontend.yaml` — Deployment + Service (ClusterIP) für Frontend
- `k8s/ingress.yaml` — Ingress, routes `/api` -> backend und `/` -> frontend
- `k8s/postgres.yaml` — Service + Deployment für Postgres (optional)
- `k8s/postgres-secret.yaml` — Secret mit Default-Werten (bitte ersetzen)
- `k8s/volume-claim.yaml` — PVC für Postgres-Daten

Wichtig: Bevor du `kubectl apply` ausführst, ersetze in den `k8s/*.yaml` Dateien die Platzhalter-Image-Namen
`REPLACE_WITH_REGISTRY/...` mit dem tatsächlichen Registry-Pfad, z.B. `ghcr.io/<your-org>/challengr-backend:TAG`.
Die Standard-Einstellung in diesem Repository verwendet GHCR (GitHub Container Registry) unter `ghcr.io/basti010203`.

Voraussetzungen
- `kubectl` ist konfiguriert und zeigt auf den LeoCloud-Cluster
- Namespace: `student-it220257` (oder `student-<HTL_USER>`) — wir zeigen Beispiele mit `student-it220257`
- Du hast Zugriff auf eine Container-Registry (z.B. GHCR oder DockerHub) oder kannst Images in die LeoCloud-Registry pushen

1) Namespace anlegen (falls noch nicht vorhanden)

```bash
kubectl create namespace student-it220257
kubectl config set-context --current --namespace=student-it220257
```

2) Build & Push Images (Beispiel GHCR)

Ersetze `<REGISTRY>` mit z. B. `ghcr.io/<GH_USER>` oder deiner Registry.

Backend bauen und pushen

```bash
# im Repo-Root
docker build -f Backend/challengrbackend/Dockerfile -t ghcr.io/basti010203/challengr-backend:latest Backend/challengrbackend
docker push ghcr.io/basti010203/challengr-backend:latest
```

Frontend bauen und pushen

```bash
docker build -f WebApp/Dockerfile -t ghcr.io/basti010203/challengr-frontend:latest WebApp
docker push ghcr.io/basti010203/challengr-frontend:latest
```

3) (Optional) Postgres secret anpassen

Die Datei `k8s/postgres-secret.yaml` enthält standardmäßig base64('postgres'). Ersetze die Werte oder erzeuge ein Secret mit:

```bash
kubectl -n student-it220257 create secret generic postgres-secret \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=securepassword \
  --from-literal=POSTGRES_DB=postgres
```

4) Deploy Manifeste anwenden

```bash
# apply postgres (optional)
kubectl -n student-it220257 apply -f k8s/postgres-secret.yaml
kubectl -n student-it220257 apply -f k8s/volume-claim.yaml
kubectl -n student-it220257 apply -f k8s/postgres.yaml

# apply backend + frontend + ingress
kubectl -n student-it220257 apply -f k8s/backend.yaml
kubectl -n student-it220257 apply -f k8s/frontend.yaml
kubectl -n student-it220257 apply -f k8s/ingress.yaml
```

5) Kontrolle & Test

```bash
kubectl -n student-it220257 get pods
kubectl -n student-it220257 get svc
kubectl -n student-it220257 get ingress

# Logs backend
kubectl -n student-it220257 logs deployment/challengr-backend

# Browser test:
https://it220257.cloud.htl-leonding.ac.at/
# Backend-API (beispielsweise):
https://it220257.cloud.htl-leonding.ac.at/api/your-endpoint
```

Wichtiges zu CORS und Backend-Konfiguration
- Die Quarkus-Konfiguration (`src/main/resources/application.properties`) verwendet derzeit `quarkus.http.cors.origins=http://localhost:5173`.
  Für LeoCloud setzen wir in `k8s/backend.yaml` die Umgebungsvariable `QUARKUS_HTTP_CORS_ORIGINS` auf `https://it220257.cloud.htl-leonding.ac.at`.
- Die Datenbank-URL wird per Umgebungsvariable `QUARKUS_DATASOURCE_JDBC_URL` auf `jdbc:postgresql://postgres:5432/postgres` gesetzt.

Updates
- Neue Images bauen & pushen
- `kubectl -n student-it220257 set image deployment/challengr-backend challengr-backend=REPLACE_WITH_REGISTRY/challengr-backend:TAG`
- oder `kubectl rollout restart deployment/challengr-backend -n student-it220257`

Troubleshooting
- `kubectl describe ingress challengr-ingress -n student-it220257`
- `kubectl logs deployment/challengr-backend -n student-it220257`
- Prüfe, ob Images tatsächlich unter dem angegebenen Registry-Pfad vorhanden sind

Sicherheits- und Hinweise
- Ersetze Secrets und verwende starke Passwörter
- Wenn du eine öffentliche Registry verwendest, achte auf private Daten

Support & Erweiterungen
- Optional: Ersetze den Postgres-Deployment durch ein Managed-DB-Produkt falls vorhanden
- Optional: CI Workflow anpassen, um Images automatisch nach Push zu bauen und zu deployen
