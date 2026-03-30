#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

BACKGROUND=0
for arg in "$@"; do
  case "$arg" in
    --background|--daemon|-d) BACKGROUND=1 ;;
  esac
done

if [[ ! -f "$SCRIPT_DIR/venv/bin/activate" ]]; then
  echo "ERROR: venv not found. Run setup.sh first (from the directory that contains it)." >&2
  exit 1
fi

PORT="${PORT:-8000}"
if command -v ss >/dev/null 2>&1; then
  if ss -tlnp 2>/dev/null | grep -qE ":${PORT}\\s"; then
    echo "ERROR: Port ${PORT} is already in use — another instance may be running." >&2
    ss -tlnp 2>/dev/null | grep -E ":${PORT}\\s" || true
    exit 1
  fi
elif command -v fuser >/dev/null 2>&1; then
  if fuser "${PORT}/tcp" 2>/dev/null | grep -q .; then
    echo "ERROR: Port ${PORT} is already in use." >&2
    exit 1
  fi
fi

mkdir -p "$SCRIPT_DIR/logs"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/venv/bin/activate"
export PYTHONPATH="${SCRIPT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"

URL="http://127.0.0.1:${PORT}/"
if [[ "$BACKGROUND" -eq 1 ]]; then
  nohup python "$SCRIPT_DIR/src/main.py" >> "$SCRIPT_DIR/logs/server.log" 2>&1 &
  echo $! > "$SCRIPT_DIR/.server.pid"
  sleep 1
  if ss -tlnp 2>/dev/null | grep -qE ":${PORT}\\s"; then
    echo "Dashboard is running in the background (PID $(cat "$SCRIPT_DIR/.server.pid"))."
  else
    echo "Started background process; if the page does not load, check: $SCRIPT_DIR/logs/server.log" >&2
  fi
  echo "Open: $URL"
  echo "Stop with: $SCRIPT_DIR/stop.sh"
  exit 0
fi

echo "Starting dashboard — open: $URL"
echo "Leave this terminal open while you use the app. Press Ctrl+C to stop."
echo "(Or run: $SCRIPT_DIR/start.sh --background  to run detached.)"
exec python "$SCRIPT_DIR/src/main.py"
