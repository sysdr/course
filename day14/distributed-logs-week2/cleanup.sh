#!/usr/bin/env bash
# Stop running Docker containers and prune unused Docker resources.
# WARNING: `docker system prune -af --volumes` applies to ALL Docker on this machine,
# not only this folder (removes unused images/volumes/networks globally).
# Run: cd distributed-logs-week2 && ./cleanup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[cleanup] Project directory: $SCRIPT_DIR"

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    echo "[cleanup] Docker: stopping running containers..."
    mapfile -t RUNNING < <(docker ps -q 2>/dev/null || true)
    if ((${#RUNNING[@]})); then
      docker stop "${RUNNING[@]}"
    else
      echo "[cleanup] No running containers."
    fi

    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
      for c in docker-compose.yml compose.yml; do
        if [[ -f "$SCRIPT_DIR/$c" ]]; then
          echo "[cleanup] docker compose down ($c)..."
          (cd "$SCRIPT_DIR" && docker compose -f "$c" down --remove-orphans 2>/dev/null || true)
        fi
      done
    fi

    echo "[cleanup] Pruning unused containers, images, networks, volumes, build cache..."
    docker system prune -af --volumes
    echo "[cleanup] Docker cleanup finished."
  else
    echo "[cleanup] Docker daemon not reachable; skipping Docker steps."
  fi
else
  echo "[cleanup] docker not installed; skipping Docker steps."
fi

echo "[cleanup] Optional: stop Docker daemon (requires root): sudo systemctl stop docker"
echo "[cleanup] Done."
