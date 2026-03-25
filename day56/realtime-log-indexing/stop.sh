#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="$PROJECT_DIR/run"
PID_DIR="$RUN_DIR/pids"

WEB_PID_FILE="$PID_DIR/web.pid"
REDIS_PID_FILE="$PID_DIR/redis.pid"

log() {
  echo "[$(date -Is)] $*"
}

stop_pidfile() {
  local pid_file="$1"
  if [ ! -f "$pid_file" ]; then
    return 0
  fi
  local pid
  pid="$(<"$pid_file")"
  [ -n "$pid" ] || return 0

  if kill -0 "$pid" 2>/dev/null; then
    log "Stopping PID ${pid} from ${pid_file}..."
    kill "$pid" 2>/dev/null || true
    # Give a moment to exit cleanly
    for _ in $(seq 1 15); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.2
    done
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$pid_file" || true
}

stop_redis() {
  # If redis-cli exists, attempt a clean shutdown.
  if command -v redis-cli >/dev/null 2>&1 && [ -f "$REDIS_PID_FILE" ]; then
    redis-cli -p 6379 shutdown >/dev/null 2>&1 || true
  fi
  stop_pidfile "$REDIS_PID_FILE"
}

stop_web() {
  stop_pidfile "$WEB_PID_FILE"
}

log "Stopping demo services..."
stop_web
stop_redis

# If we started via docker-compose, stop the stack too.
if command -v docker >/dev/null 2>&1 && [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
  (cd "$PROJECT_DIR" && docker compose down -v --remove-orphans >/dev/null 2>&1) || true
fi

log "Done."
