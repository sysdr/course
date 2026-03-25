#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="$PROJECT_DIR/run"
PID_DIR="$RUN_DIR/pids"
LOG_DIR="$RUN_DIR/logs"

mkdir -p "$PID_DIR" "$LOG_DIR"

WEB_PORT=8080
REDIS_PORT=6379

WEB_PID_FILE="$PID_DIR/web.pid"
REDIS_PID_FILE="$PID_DIR/redis.pid"

log() {
  echo "[$(date -Is)] $*"
}

port_is_listening() {
  local port="$1"
  local count
  count="$(ss -ltnH "sport = :${port}" 2>/dev/null | wc -l | tr -d ' ')"
  [ "${count}" -gt 0 ]
}

pid_is_running() {
  local pid_file="$1"
  [ -f "$pid_file" ] || return 1
  local pid
  pid="$(<"$pid_file")"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

ensure_venv_and_deps() {
  if [ ! -x "$PROJECT_DIR/venv/bin/python" ]; then
    log "Creating venv..."
    python3 -m venv "$PROJECT_DIR/venv"
  fi

  # shellcheck disable=SC1091
  source "$PROJECT_DIR/venv/bin/activate"

  log "Installing Python dependencies (venv)..."
  pip install --upgrade pip >/dev/null
  pip install -r "$PROJECT_DIR/requirements.txt" >/dev/null
}

ensure_redis() {
  mkdir -p "$PROJECT_DIR/data/redis"

  if port_is_listening "$REDIS_PORT"; then
    log "Redis already listening on ${REDIS_PORT} (skipping start)."
    return 0
  fi

  log "Starting Redis on ${REDIS_PORT}..."
  redis-server \
    --port "$REDIS_PORT" \
    --dir "$PROJECT_DIR/data/redis" \
    --appendonly yes \
    --save "" \
    --daemonize yes \
    --pidfile "$REDIS_PID_FILE" \
    >/dev/null 2>&1 || {
      log "Failed to start redis-server. Ensure Redis is installed and on PATH."
      exit 1
    }
}

ensure_web() {
  if port_is_listening "$WEB_PORT"; then
    if pid_is_running "$WEB_PID_FILE"; then
      log "Web app already running (PID tracked)."
      return 0
    fi
    log "Port ${WEB_PORT} already in use, but no tracked PID found."
    log "Stop the previous instance (run stop.sh) and retry."
    exit 1
  fi

  ensure_venv_and_deps

  # Demo-friendly indexing parameters (so disk/memory segment metrics quickly become non-zero).
  # These env vars are only applied to the server process.
  log "Starting web application on ${WEB_PORT}..."
  (
    INDEX_MEMORY_SEGMENT_MAX_SIZE=40 \
    INDEX_SEGMENT_MERGE_THRESHOLD=2 \
    python -m src.main
  ) >"$LOG_DIR/web.log" 2>&1 &

  echo $! > "$WEB_PID_FILE"

  # Wait for readiness
  log "Waiting for web app readiness (/api/stats)..."
  for _ in $(seq 1 60); do
    if curl -fsS "http://localhost:${WEB_PORT}/api/stats" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  log "Web app did not become ready in time. Last logs:"
  tail -n 80 "$LOG_DIR/web.log" || true
  exit 1
}

run_demo_workload() {
  local count="${1:-200}"

  log "Generating ${count} sample logs (via API)..."
  curl -fsS -X POST "http://localhost:${WEB_PORT}/api/generate-sample" \
    -H "Content-Type: application/json" \
    -d "{\"count\": ${count}}" >/dev/null

  # Wait a bit for the indexing loop to consume logs.
  sleep 2

  log "Running sample searches to update dashboard metrics..."
  curl -fsS -X POST "http://localhost:${WEB_PORT}/api/search" \
    -H "Content-Type: application/json" \
    -d '{"query":"user authentication","filters":{},"limit":25}' >/dev/null

  curl -fsS -X POST "http://localhost:${WEB_PORT}/api/search" \
    -H "Content-Type: application/json" \
    -d '{"query":"payment processing","filters":{},"limit":25}' >/dev/null
}

wait_for_dashboard_metrics() {
  log "Validating dashboard metrics are non-zero..."

  # Wait until the backend has indexed enough docs and performed searches.
  for _ in $(seq 1 60); do
    stats="$(curl -fsS "http://localhost:${WEB_PORT}/api/stats" 2>/dev/null || true)"
    if [ -n "$stats" ]; then
      ok="$(python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); im=d.get("index_manager",{}); si=d.get("search_interface",{}); sp=d.get("stream_processor",{}); keys=[im.get("total_documents",0), im.get("avg_indexing_latency_ms",0), im.get("memory_segments",0), im.get("disk_segments",0), si.get("searches_performed",0), si.get("avg_search_time_ms",0), si.get("avg_results_per_search",0), sp.get("logs_processed",0)]; print(1 if all((float(k) > 0) for k in keys) else 0)' <<<"$stats")"
      if [ "$ok" = "1" ]; then
        echo "$stats" | python3 -m json.tool >/dev/null 2>&1 || true
        log "Dashboard metrics look good."
        return 0
      fi
    fi
    sleep 1
  done

  log "Dashboard metrics still contain zeros after waiting."
  curl -fsS "http://localhost:${WEB_PORT}/api/stats" || true
  exit 1
}

ensure_docker_compose() {
  if ! command -v docker >/dev/null 2>&1; then
    log "Docker is required for fallback when redis-server is not available."
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    log "Docker Compose is required for fallback."
    exit 1
  fi

  if port_is_listening "$WEB_PORT"; then
    log "Web port ${WEB_PORT} already listening (skipping docker compose start)."
  else
    log "Starting services via docker-compose..."
    (
      cd "$PROJECT_DIR"
      docker compose up -d --build >/dev/null 2>&1 || docker compose up -d --build
    )
  fi

  log "Waiting for dockerized web app readiness (/api/stats)..."
  for _ in $(seq 1 90); do
    if curl -fsS "http://localhost:${WEB_PORT}/api/stats" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  log "Dockerized web app did not become ready in time. Trying to show logs (if any)..."
  (cd "$PROJECT_DIR" && docker compose logs --no-color --tail=200 2>/dev/null || true)
  exit 1
}

main() {
  if port_is_listening "$REDIS_PORT" || command -v redis-server >/dev/null 2>&1; then
    ensure_redis
    ensure_web
  else
    # Fallback for environments where redis-server binary isn't installed.
    ensure_docker_compose
  fi

  run_demo_workload 200
  wait_for_dashboard_metrics

  log "Demo is running. Dashboard: http://localhost:${WEB_PORT}"
}

main "$@"
