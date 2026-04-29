#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "[cleanup] stopping local app (if running)"
./stop.sh >/dev/null 2>&1 || true

if command -v docker >/dev/null 2>&1; then
  echo "[cleanup] stopping all running containers"
  RUNNING_IDS="$(docker ps -q 2>/dev/null || true)"
  if [ -n "${RUNNING_IDS}" ]; then
    docker stop ${RUNNING_IDS} >/dev/null || true
  fi

  echo "[cleanup] pruning unused docker resources (containers/images/networks/volumes)"
  docker container prune -f >/dev/null || true
  docker image prune -af >/dev/null || true
  docker network prune -f >/dev/null || true
  docker volume prune -f >/dev/null || true
else
  echo "[cleanup] docker not installed; skipping docker cleanup"
fi

echo "[cleanup] removing local dev artifacts"
rm -rf \
  venv \
  node_modules \
  .pytest_cache \
  **/__pycache__ \
  2>/dev/null || true

find . -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true

echo "[cleanup] done"
