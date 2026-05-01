#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
_free_port() {
  local p="${1:-8175}"
  if command -v fuser >/dev/null 2>&1; then fuser -k "${p}/tcp" 2>/dev/null || true
  elif command -v lsof >/dev/null 2>&1; then
    local pids
    pids="$(lsof -t -i:"$p" -sTCP:LISTEN 2>/dev/null || true)"
    [ -n "$pids" ] && kill $pids 2>/dev/null || true
  fi
}
[ -f .server.pid ] && kill "$(cat .server.pid)" 2>/dev/null || true
rm -f .server.pid
_free_port 8175
echo "--- Creating virtual environment ---"
PY="$(command -v python3.11 2>/dev/null || command -v python3 2>/dev/null)"
[[ -z "$PY" ]] && { echo "ERROR: Need python3 (or python3.11)." >&2; exit 1; }
"$PY" -m venv .venv
source .venv/bin/activate
echo "--- Installing dependencies ---"
pip install -q -r requirements.txt
echo "--- Running unit & integration tests ---"
python -m pytest tests/ -v --tb=short
echo ""
echo "--- Starting CX Monitoring API on http://localhost:8175 ---"
echo "    Dashboard: http://localhost:8175/"
echo "    Metrics:   http://localhost:8175/metrics/cx"
echo ""
uvicorn src.api.server:app --host 0.0.0.0 --port 8175 &
echo $! > .server.pid
sleep 3
echo "--- Health check ---"
curl -s http://localhost:8175/health | python3 -m json.tool || true
echo ""
echo "--- Sample CX snapshot (after pipeline runs) ---"
sleep 8
curl -s http://localhost:8175/metrics/cx | python3 -m json.tool || true
echo ""
echo "Server PID: $(cat .server.pid). Open http://localhost:8175 in your browser."
