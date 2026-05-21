#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

NAMESPACE="${K8S_NAMESPACE:-student-it220257}"
IMAGE_OWNER="${GHCR_OWNER:-htl-leo-itp-25-27-4-5bhitm}"
BACKEND_IMAGE="ghcr.io/${IMAGE_OWNER}/challengr-backend:latest"
DASHBOARD_IMAGE="ghcr.io/${IMAGE_OWNER}/challengr-dashboard:latest"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

usage() {
  cat <<EOF
Usage: ./scripts/deploy-cloud.sh [backend|dashboard|both]

Deploy target:
  backend   Build + push backend image and restart backend deployment
  dashboard Build + push dashboard image and restart dashboard deployment
  both      Build + push both images and restart both deployments

Optional environment variables:
  K8S_NAMESPACE   (default: ${NAMESPACE})
  GHCR_OWNER      (default: ${IMAGE_OWNER})
  DOCKER_PLATFORM (default: ${PLATFORM})

Examples:
  ./scripts/deploy-cloud.sh backend
  ./scripts/deploy-cloud.sh dashboard
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

build_dashboard() {
  echo "\n[dashboard] Docker buildx push -> $DASHBOARD_IMAGE"
  cd "$ROOT_DIR/Dashboard"
  docker buildx build \
    --platform "$PLATFORM" \
    -f Dockerfile \
    -t "$DASHBOARD_IMAGE" \
    --push .

  echo "[dashboard] Restart deployment..."
  kubectl -n "$NAMESPACE" rollout restart deployment/challengr-dashboard
  kubectl -n "$NAMESPACE" rollout status deployment/challengr-dashboard
}

deploy_keycloak() {
  echo "\n[keycloak] Deploying Keycloak..."
  kubectl apply -f "$ROOT_DIR/k8s/keycloak.yaml"
}

TARGET="${1:-both}"

if [[ "$TARGET" == "-h" || "$TARGET" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$TARGET" != "backend" && "$TARGET" != "dashboard" && "$TARGET" != "both" ]]; then
  echo "❌ Invalid target: $TARGET"
  usage
  exit 1
fi

require_cmd docker
require_cmd kubectl

if [[ "$TARGET" == "backend" || "$TARGET" == "both" ]]; then
  build_backend
fi

if [[ "$TARGET" == "dashboard" || "$TARGET" == "both" ]]; then
  build_dashboard
fi

# Keycloak bei "both" mit deployen
if [[ "$TARGET" == "both" ]]; then
  deploy_keycloak
fi

echo "\n✅ Deploy finished ($TARGET)"
echo "Cloud URL: https://it220257.cloud.htl-leonding.ac.at"
