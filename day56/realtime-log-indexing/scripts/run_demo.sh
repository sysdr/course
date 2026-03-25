#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Starting demo services..."
"$PROJECT_DIR/start.sh"

echo "🌐 Access the dashboard at: http://localhost:8080"
echo "🔍 Try searching for: 'user', 'auth', 'payment', 'error'"
echo ""
echo "Press Ctrl+C to stop the demo"

trap "\"$PROJECT_DIR/stop.sh\" >/dev/null 2>&1 || true; exit 0" INT TERM
while true; do
  sleep 1
done
