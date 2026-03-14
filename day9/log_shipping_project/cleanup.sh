#!/usr/bin/env bash
# Cleanup script for Log Shipping Project
# Stops containers and removes unused Docker resources.
# Run from: log_shipping_project/

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Stopping Docker Compose services ==="
if [ -f assignment/docker-compose.yml ]; then
  docker-compose -f assignment/docker-compose.yml down --remove-orphans 2>/dev/null || true
fi
if [ -f main_project/docker-compose.yml ]; then
  docker-compose -f main_project/docker-compose.yml down --remove-orphans 2>/dev/null || true
fi

echo "=== Stopping any remaining project containers ==="
docker ps -a --filter "name=assignment-" --filter "name=main_project-" --filter "name=log-server" --filter "name=log-client" -q 2>/dev/null | xargs -r docker stop 2>/dev/null || true
docker ps -a --filter "name=assignment-" --filter "name=main_project-" --filter "name=log-server" --filter "name=log-client" -q 2>/dev/null | xargs -r docker rm 2>/dev/null || true

echo "=== Removing unused Docker containers ==="
docker container prune -f

echo "=== Removing unused Docker images (dangling) ==="
docker image prune -f

echo "=== Removing unused Docker networks ==="
docker network prune -f

echo "=== Removing Python cache and local artifacts ==="
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true
find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name ".coverage" -delete 2>/dev/null || true
find . -type f -name "undelivered_logs.json" -delete 2>/dev/null || true
# Do not remove .venv here; it's in .gitignore and user may want to keep it

echo "=== Cleanup complete ==="
