#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

NAMESPACE="${K8S_NAMESPACE:-student-it220257}"
IMAGE_OWNER="${GHCR_OWNER:-htl-leo-itp-25-27-4-5bhitm}"
BACKEND_IMAGE="ghcr.io/${IMAGE_OWNER}/challengr-backend:latest"
WEBAPP_IMAGE="ghcr.io/${IMAGE_OWNER}/challengr-webapp:latest"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

usage() {
  cat <<EOF
Usage: ./scripts/deploy-cloud.sh [backend|webapp|both]

Deploy target:
  backend   Build + push backend image and restart backend deployment
  webapp    Build + push webapp image and restart webapp deployment
  both      Build + push both images and restart both deployments

Optional environment variables:
  K8S_NAMESPACE   (default: ${NAMESPACE})
  GHCR_OWNER      (default: ${IMAGE_OWNER})
  DOCKER_PLATFORM (default: ${PLATFORM})

Examples:
  ./scripts/deploy-cloud.sh backend
  ./scripts/deploy-cloud.sh webapp
  ./scripts/deploy-cloud.sh both
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Missing command: $cmd"
    exit 1
  fi
}

build_backend() {
  echo "\n[backend] Maven package..."
  cd "$ROOT_DIR/Backend/challengrbackend"
  ./mvnw clean package -DskipTests

  echo "[backend] Docker buildx push -> $BACKEND_IMAGE"
  docker buildx build \
    --platform "$PLATFORM" \
    -f src/main/docker/Dockerfile.txt \
    -t "$BACKEND_IMAGE" \
    --push .

  echo "[backend] Restart deployment..."
  kubectl -n "$NAMESPACE" rollout restart deployment/challengr-backend
  kubectl -n "$NAMESPACE" rollout status deployment/challengr-backend
}

build_webapp() {
  echo "\n[webapp] Docker buildx push -> $WEBAPP_IMAGE"
  cd "$ROOT_DIR/WebApp"
  docker buildx build \
    --platform "$PLATFORM" \
    -f Dockerfile \
    -t "$WEBAPP_IMAGE" \
    --push .

  echo "[webapp] Restart deployment..."
  kubectl -n "$NAMESPACE" rollout restart deployment/challengr-webapp
  kubectl -n "$NAMESPACE" rollout status deployment/challengr-webapp
}

TARGET="${1:-both}"

if [[ "$TARGET" == "-h" || "$TARGET" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$TARGET" != "backend" && "$TARGET" != "webapp" && "$TARGET" != "both" ]]; then
  echo "❌ Invalid target: $TARGET"
  usage
  exit 1
fi

require_cmd docker
require_cmd kubectl

if [[ "$TARGET" == "backend" || "$TARGET" == "both" ]]; then
  build_backend
fi

if [[ "$TARGET" == "webapp" || "$TARGET" == "both" ]]; then
  build_webapp
fi

echo "\n✅ Deploy finished ($TARGET)"
echo "Cloud URL: https://it220257.cloud.htl-leonding.ac.at"
