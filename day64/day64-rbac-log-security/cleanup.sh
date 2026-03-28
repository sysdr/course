#!/bin/bash
# Stop local dev processes, tear down project Compose stack, prune unused Docker data.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE="${ROOT}/docker-compose.yml"

if [[ -f "${ROOT}/stop.sh" ]]; then
  bash "${ROOT}/stop.sh" || true
fi

if command -v docker >/dev/null 2>&1; then
  if [[ -f "$COMPOSE" ]]; then
    (cd "$ROOT" && docker compose -f "$COMPOSE" down --remove-orphans -v 2>/dev/null) || true
    (cd "$ROOT" && docker-compose -f "$COMPOSE" down --remove-orphans -v 2>/dev/null) || true
  fi
  docker container prune -f
  docker network prune -f
  docker image prune -f
  docker builder prune -f 2>/dev/null || true
  if [[ "${CLEAN_ALL_UNUSED_IMAGES:-}" == "1" ]]; then
    docker image prune -a -f
  fi
  echo "Docker prune complete (set CLEAN_ALL_UNUSED_IMAGES=1 to also remove unused tagged images)."
else
  echo "Docker not installed; skipped container/image cleanup."
fi

# Python bytecode cache (under backend/)
if [[ -d "${ROOT}/backend" ]]; then
  find "${ROOT}/backend" -type d -name __pycache__ | while read -r d; do rm -rf "$d"; done
  find "${ROOT}/backend" -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true
  echo "Removed __pycache__ and .pyc/.pyo under backend/."
fi
