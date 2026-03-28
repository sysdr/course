#!/bin/bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for f in "${ROOT}/.backend.pid" "${ROOT}/.frontend.pid"; do
  if [[ -f "$f" ]]; then
    pid=$(cat "$f")
    kill "$pid" 2>/dev/null || true
    rm -f "$f"
  fi
done
for port in 8000 3000; do
  if command -v lsof >/dev/null 2>&1; then
    lsof -ti:"$port" | xargs -r kill 2>/dev/null || true
  elif command -v fuser >/dev/null 2>&1; then
    fuser -k "$port/tcp" 2>/dev/null || true
  fi
done
pkill -f "react-scripts start" 2>/dev/null || true
echo "Stopped."
