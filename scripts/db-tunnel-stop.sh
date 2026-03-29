#!/usr/bin/env zsh
set -euo pipefail

LOCAL_PORT="15432"
PID_FILE="/tmp/challengr-pf.pid"

if [[ -f "$PID_FILE" ]]; then
  PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$PID" ]] && kill -0 "$PID" >/dev/null 2>&1; then
    kill "$PID" >/dev/null 2>&1 || true
    echo "Stopped DB tunnel pid=$PID"
  fi
  rm -f "$PID_FILE"
fi

# fallback by port
PIDS="$(lsof -t -iTCP:${LOCAL_PORT} -sTCP:LISTEN 2>/dev/null || true)"
if [[ -n "$PIDS" ]]; then
  echo "$PIDS" | xargs kill >/dev/null 2>&1 || true
  echo "Stopped listeners on port ${LOCAL_PORT}"
fi

echo "Done"
