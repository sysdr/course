#!/bin/bash
# Stop local services and Docker resources for this project; prune unused Docker data.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo "==> Stopping local dashboard (if running)..."
if [[ -x "$SCRIPT_DIR/stop.sh" ]]; then
  "$SCRIPT_DIR/stop.sh" 2>/dev/null || true
fi

if command -v docker >/dev/null 2>&1; then
  echo "==> Stopping Docker Compose stack for this project..."
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" down --remove-orphans 2>/dev/null || true
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f "$SCRIPT_DIR/docker-compose.yml" down --remove-orphans 2>/dev/null || true
  fi

  echo "==> Pruning stopped containers..."
  docker container prune -f

  echo "==> Pruning unused images..."
  docker image prune -a -f

  echo "==> Pruning unused networks..."
  docker network prune -f

  echo "==> Pruning build cache..."
  docker builder prune -f

  echo "==> Docker system prune (unused data)..."
  docker system prune -f
else
  echo "(Docker not installed; skipped container/image cleanup.)"
fi

echo "==> Removing local ephemeral files (not for git)..."
rm -f "$SCRIPT_DIR/.server.pid"
rm -rf "$SCRIPT_DIR/logs"
rm -rf "$SCRIPT_DIR/.pytest_cache"
rm -rf "$SCRIPT_DIR/venv"

while IFS= read -r -d '' dir; do
  rm -rf "$dir"
done < <(find "$SCRIPT_DIR" \( -path "$SCRIPT_DIR/.git" \) -prune -o -type d -name __pycache__ -print0 2>/dev/null)

find "$SCRIPT_DIR" \( -path "$SCRIPT_DIR/.git" \) -prune -o -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete 2>/dev/null || true

echo "Cleanup finished."
echo "Recreate Python env: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
