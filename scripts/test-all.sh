#!/usr/bin/env zsh
# Führt alle Tests aus: Backend (Quarkus, In-Memory-DB) und iOS-App (Simulator).
#
#   ./scripts/test-all.sh            alles
#   ./scripts/test-all.sh backend    nur Backend
#   ./scripts/test-all.sh ios        nur iOS-App (Swift)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-all}"

run_backend() {
  echo "\n[backend] mvn test ..."
  cd "$ROOT_DIR/Backend/challengrbackend"
  ./mvnw -q test
  echo "[backend] ✅ Tests grün"
}

run_ios() {
  local project_dir="$1"
  # Erster verfügbarer iPhone-Simulator
  local udid
  udid=$(xcrun simctl list devices available | grep -m1 -E "iPhone" | grep -oE "[0-9A-F-]{36}")
  if [[ -z "$udid" ]]; then
    echo "❌ Kein iPhone-Simulator gefunden"
    exit 1
  fi

  echo "\n[ios] $project_dir auf Simulator $udid ..."
  cd "$ROOT_DIR/$project_dir"
  xcodebuild test \
    -project Challengr.xcodeproj \
    -scheme Challengr \
    -destination "platform=iOS Simulator,id=$udid" \
    CODE_SIGNING_ALLOWED=NO \
    | grep -E "error:|Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)" || true

  # Ergebnis prüfen (grep oben schluckt den Exit-Code von xcodebuild)
  if [[ ${pipestatus[1]} -ne 0 ]]; then
    echo "[ios] ❌ Tests fehlgeschlagen in $project_dir"
    exit 1
  fi
  echo "[ios] ✅ Tests grün ($project_dir)"
}

case "$TARGET" in
  backend) run_backend ;;
  ios)     run_ios "Swift/Challengr"; run_ios "Swift Kopie/Challengr" ;;
  all)     run_backend; run_ios "Swift/Challengr"; run_ios "Swift Kopie/Challengr" ;;
  *) echo "Usage: ./scripts/test-all.sh [all|backend|ios]"; exit 1 ;;
esac

echo "\n✅ Alle Tests grün ($TARGET)"
