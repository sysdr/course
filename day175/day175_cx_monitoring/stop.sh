#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
free_port(){
  local p="${1:-8175}"
  if command -v fuser >/dev/null 2>&1; then fuser -k "${p}/tcp" 2>/dev/null || true
  elif command -v lsof >/dev/null 2>&1; then
    local pids
    pids="$(lsof -t -i:"$p" -sTCP:LISTEN 2>/dev/null || true)"
    [ -n "$pids" ] && kill $pids 2>/dev/null || true
  fi
}
if [ -f .server.pid ]; then
  kill "$(cat .server.pid)" 2>/dev/null && echo "Server stopped." || echo "Already stopped or PID stale."
  rm -f .server.pid
fi
free_port 8175
