#!/bin/bash
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="${ROOT}/backend"
FRONTEND="${ROOT}/frontend"
VENV_PY="${BACKEND}/venv/bin/python"
VENV_PIP="${BACKEND}/venv/bin/pip"

for p in "$BACKEND/requirements.txt" "$FRONTEND/package.json" "$BACKEND/src/main.py"; do
  if [[ ! -f "$p" ]]; then
    echo "Missing required file: $p"
    exit 1
  fi
done

if [[ ! -x "$VENV_PY" ]]; then
  echo "Creating Python venv..."
  python3 -m venv "${BACKEND}/venv"
  "$VENV_PIP" install -r "${BACKEND}/requirements.txt"
fi

if [[ ! -d "${FRONTEND}/node_modules" ]]; then
  echo "Installing frontend dependencies..."
  (cd "$FRONTEND" && npm install)
fi

ENV_FILE="${BACKEND}/config/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  mkdir -p "${BACKEND}/config"
  key="$(python3 -c "import secrets; print(secrets.token_hex(32))")"
  printf 'JWT_SECRET_KEY=%s\n' "$key" > "$ENV_FILE"
  echo "Created ${ENV_FILE} with a random JWT_SECRET_KEY (local dev only; gitignored)."
fi

port_pids() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -ti:"$port" 2>/dev/null || true
  elif command -v fuser >/dev/null 2>&1; then
    fuser "$port/tcp" 2>/dev/null | tr -s ' ' '\n' | grep -E '^[0-9]+$' || true
  elif command -v ss >/dev/null 2>&1; then
    ss -ltnp 2>/dev/null | grep ":${port} " | sed -n 's/.*pid=\([0-9]*\).*/\1/p' || true
  fi
}

for port in 8000 3000; do
  pids=$(port_pids "$port" | sort -u)
  if [[ -n "$pids" ]]; then
    echo "Port $port in use by PID(s): $pids — stopping to avoid duplicate services."
    for pid in $pids; do kill "$pid" 2>/dev/null || true; done
    sleep 1
  fi
done

mkdir -p "${ROOT}/logs"

echo "Starting backend on :8000..."
cd "$BACKEND"
nohup "$VENV_PY" src/main.py >> "${ROOT}/logs/backend.log" 2>&1 &
echo $! > "${ROOT}/.backend.pid"
cd "$ROOT"

for i in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:8000/health" >/dev/null; then break; fi
  sleep 1
done
curl -sf "http://127.0.0.1:8000/health" >/dev/null || { echo "Backend failed to start; see ${ROOT}/logs/backend.log"; exit 1; }

echo "Starting frontend on :3000..."
cd "$FRONTEND"
BROWSER=none nohup npm start >> "${ROOT}/logs/frontend.log" 2>&1 &
echo $! > "${ROOT}/.frontend.pid"
cd "$ROOT"

if [[ -x "${ROOT}/scripts/demo.sh" ]]; then
  sleep 3
  bash "${ROOT}/scripts/demo.sh" || true
fi

echo "Services started. Backend PID $(cat "${ROOT}/.backend.pid"), frontend PID $(cat "${ROOT}/.frontend.pid")"
echo "Dashboard: http://localhost:3000  API: http://localhost:8000/docs"
