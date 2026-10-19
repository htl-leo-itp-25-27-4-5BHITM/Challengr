#!/usr/bin/env zsh
# Richtet den App-Store-Connect-API-Schlüssel ein, damit das Dashboard TestFlight-Feedback zeigt.
#
# Vorher in App Store Connect: Benutzer und Zugriff → Integrationen → App Store Connect API →
#   Team-Schlüssel erstellen (Zugriff: "Developer" reicht), .p8-Datei herunterladen (geht nur EINMAL),
#   Issuer-ID (oben auf der Seite) und Key-ID (Spalte beim Schlüssel) notieren.
#
# Aufruf:  ./scripts/setup-appstore-api.sh <Pfad/zur/AuthKey_XXXX.p8> <Issuer-ID> <Key-ID>
#
# Speichert alles im Kubernetes-Secret "challengr-asc" (nicht im Repo) und startet das Backend neu.
set -euo pipefail
NAMESPACE="student-it220257"

P8="${1:-}"; ISSUER="${2:-}"; KEY_ID="${3:-}"
if [[ -z "$P8" || -z "$ISSUER" || -z "$KEY_ID" ]]; then
  echo "Aufruf: ./scripts/setup-appstore-api.sh <AuthKey_XXXX.p8> <Issuer-ID> <Key-ID>"
  exit 1
fi
[[ -f "$P8" ]] || { echo "❌ Datei nicht gefunden: $P8"; exit 1; }
grep -q "BEGIN PRIVATE KEY" "$P8" || { echo "❌ Das ist keine .p8-Datei von Apple"; exit 1; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "→ Secret challengr-asc anlegen/aktualisieren"
kubectl -n "$NAMESPACE" create secret generic challengr-asc \
  --from-literal=ASC_ISSUER_ID="$ISSUER" \
  --from-literal=ASC_KEY_ID="$KEY_ID" \
  --from-file=ASC_PRIVATE_KEY="$P8" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "→ Backend-Konfiguration anwenden und neu starten"
kubectl -n "$NAMESPACE" apply -f "$ROOT_DIR/k8s/backend.yaml"
kubectl -n "$NAMESPACE" rollout restart deployment/challengr-backend
kubectl -n "$NAMESPACE" rollout status deployment/challengr-backend

echo "✅ Fertig. Dashboard → Feedback öffnen. Die .p8-Datei danach sicher aufheben (z. B. Passwort-Manager) und vom Schreibtisch löschen."
