#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[1/2] Starting local WebApp (proxy -> cloud backend)..."
docker compose up -d webapp

echo "[2/2] Starting/stabilizing DB tunnel on localhost:15432..."
"$ROOT_DIR/scripts/db-tunnel-start.sh"

echo ""
echo "✅ Ready"
echo "WebApp: http://localhost:5173"
echo "DB Host: localhost"
echo "DB Port: 15432"
echo "DB Name/User/Pass: postgres/postgres/postgres"
