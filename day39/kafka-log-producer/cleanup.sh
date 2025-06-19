#!/bin/bash

# Stop all docker containers for this project
if [ -f docker-compose.yml ]; then
  echo "Stopping Docker containers..."
  docker-compose down
fi

# Kill all Python processes related to this project
PIDS=$(ps aux | grep -E 'python3 (src/main.py|web/app.py)' | grep -v grep | awk '{print $2}')
if [ ! -z "$PIDS" ]; then
  echo "Killing Python processes: $PIDS"
  kill $PIDS
else
  echo "No related Python processes running."
fi

# Stop web dashboard processes
echo "Stopping web dashboard..."
# Kill processes on common dashboard ports
DASHBOARD_PIDS=$(lsof -ti:8000,8080,3000,5000 2>/dev/null)
if [ ! -z "$DASHBOARD_PIDS" ]; then
  echo "Killing dashboard processes on ports 8000,8080,3000,5000: $DASHBOARD_PIDS"
  kill $DASHBOARD_PIDS
fi

# Kill any uvicorn or fastapi processes
UVICORN_PIDS=$(ps aux | grep -E '(uvicorn|fastapi)' | grep -v grep | awk '{print $2}')
if [ ! -z "$UVICORN_PIDS" ]; then
  echo "Killing uvicorn/fastapi processes: $UVICORN_PIDS"
  kill $UVICORN_PIDS
fi

echo "Cleanup complete." 