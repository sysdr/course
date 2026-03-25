#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "[cleanup] Stopping compose stack (if running)..."
docker compose down -v --remove-orphans >/dev/null 2>&1 || true

echo "[cleanup] Pruning unused Docker resources..."
docker container prune -f >/dev/null 2>&1 || true
docker image prune -a -f >/dev/null 2>&1 || true
docker volume prune -f >/dev/null 2>&1 || true
docker network prune -f >/dev/null 2>&1 || true
docker builder prune -af >/dev/null 2>&1 || true

echo "[cleanup] Done."

