#!/usr/bin/env bash
# Stop local API, tear down the Docker Compose stack for this project, and prune
# unused Docker objects (stopped containers, dangling images, build cache, unused networks).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "[1/3] Stopping local uvicorn (if any)..."
if [[ -x "$ROOT/stop.sh" ]]; then
  bash "$ROOT/stop.sh" || true
else
  if [[ -f .server.pid ]]; then
    kill "$(cat .server.pid)" 2>/dev/null || true
    rm -f .server.pid
  fi
  if command -v fuser >/dev/null 2>&1; then fuser -k 8175/tcp 2>/dev/null || true; fi
  if command -v lsof >/dev/null 2>&1; then
    for pid in $(lsof -t -i:8175 -sTCP:LISTEN 2>/dev/null || true); do
      kill "$pid" 2>/dev/null || true
    done
  fi
fi

echo "[2/3] Stopping Compose services and removing project images (--rmi local)..."
if command -v docker >/dev/null 2>&1; then
  if [[ -f "$ROOT/docker/docker-compose.yml" ]]; then
    COMP_PROJ="$(basename "$ROOT")"
    cd "$ROOT/docker"
    docker compose --project-name "$COMP_PROJ" down --remove-orphans --rmi local 2>/dev/null ||
      docker compose down --remove-orphans --rmi local 2>/dev/null ||
      docker-compose --project-directory "$ROOT/docker" --project-name "$COMP_PROJ" down --remove-orphans --rmi local 2>/dev/null ||
      true
    cd "$ROOT"
  fi
  echo "[3/3] Pruning Docker resources (stopped containers, unused networks, dangling images, build cache)..."
  docker container prune -f >/dev/null 2>&1 || true
  docker network prune -f >/dev/null 2>&1 || true
  docker image prune -f >/dev/null 2>&1 || true
  docker builder prune -f >/dev/null 2>&1 || true
  if [[ "${DOCKER_PRUNE_ALL_UNUSED_IMAGES:-}" == "1" ]]; then
    echo "DOCKER_PRUNE_ALL_UNUSED_IMAGES=1 → pruning all unused images (not just dangling)."
    docker image prune -a -f >/dev/null 2>&1 || true
  fi
else
  echo "(Docker not installed; skipped Compose teardown and pruning.)"
fi

echo "Cleanup finished."
