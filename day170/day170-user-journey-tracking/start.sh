#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

if [ -f .pid ]; then
  PID="$(cat .pid)"
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "Already running (PID $PID). Dashboard: http://localhost:5170"
    exit 0
  fi
  rm -f .pid
fi

if ss -ltn "( sport = :5170 )" 2>/dev/null | grep -q ":5170"; then
  echo "Port 5170 is already in use. Stop the other service first."
  exit 1
fi

source venv/bin/activate
export LOG_FILE=logs/app.log
export PORT=5170
echo "Starting User Journey Tracker → http://localhost:5170"
python3 src/api_server.py &
echo $! > .pid
sleep 1
echo "PID: $(cat .pid)"
echo "Dashboard: http://localhost:5170"
echo "API:"
echo "  http://localhost:5170/api/stats"
echo "  http://localhost:5170/api/flow"
echo "  http://localhost:5170/api/journeys"
echo "  http://localhost:5170/api/sessions"
