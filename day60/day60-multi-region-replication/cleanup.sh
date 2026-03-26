#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

shopt -s nullglob globstar

echo "[cleanup] stopping app services (if running)"
if [[ -x "./stop.sh" ]]; then
  ./stop.sh >/dev/null 2>&1 || true
fi

echo "[cleanup] stopping docker containers (if any)"
if command -v docker >/dev/null 2>&1; then
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose down --remove-orphans >/dev/null 2>&1 || true
  fi
  docker compose down --remove-orphans >/dev/null 2>&1 || true
  docker stop "$(docker ps -aq)" >/dev/null 2>&1 || true

  echo "[cleanup] pruning unused docker resources"
  docker system prune -af --volumes >/dev/null 2>&1 || true
else
  echo "[cleanup] docker not installed; skipping docker cleanup"
fi

echo "[cleanup] removing local runtime artifacts"
rm -f .main.pid .dashboard.pid .region_*.pid 2>/dev/null || true
rm -rf .pytest_cache 2>/dev/null || true
rm -rf **/__pycache__ 2>/dev/null || true
rm -f dump.rdb 2>/dev/null || true

echo "[cleanup] optional: keeping venv/ (delete manually if desired)"
echo "[cleanup] done"

