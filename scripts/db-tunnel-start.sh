#!/usr/bin/env zsh
set -euo pipefail

NAMESPACE="student-it220257"
SERVICE="challengr-postgres-service"
LOCAL_PORT="15432"
REMOTE_PORT="5432"
LOG_FILE="/tmp/challengr-pf.log"
PID_FILE="/tmp/challengr-pf.pid"

# already listening? then reuse
if lsof -nP -iTCP:${LOCAL_PORT} -sTCP:LISTEN >/dev/null 2>&1; then
  echo "DB tunnel already running on localhost:${LOCAL_PORT}"
  exit 0
fi

# cleanup stale pid
if [[ -f "$PID_FILE" ]]; then
  OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "${OLD_PID}" ]] && kill -0 "$OLD_PID" >/dev/null 2>&1; then
    kill "$OLD_PID" >/dev/null 2>&1 || true
  fi
  rm -f "$PID_FILE"
fi

nohup kubectl -n "$NAMESPACE" port-forward "svc/$SERVICE" "${LOCAL_PORT}:${REMOTE_PORT}" >"$LOG_FILE" 2>&1 &
PF_PID=$!
echo "$PF_PID" > "$PID_FILE"

# wait up to ~6s
for _ in {1..12}; do
  if lsof -nP -iTCP:${LOCAL_PORT} -sTCP:LISTEN >/dev/null 2>&1; then
    echo "DB tunnel running (pid=${PF_PID}) on localhost:${LOCAL_PORT}"
    exit 0
  fi
  sleep 0.5
done

echo "❌ DB tunnel did not start. Last log lines:"
tail -n 30 "$LOG_FILE" || true
exit 1
