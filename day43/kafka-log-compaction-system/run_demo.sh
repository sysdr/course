#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "🎯 Kafka Log Compaction Complete Demo"
echo "===================================="

if [ ! -f "config.yaml" ]; then
    echo "❌ Run this script from the project root (config.yaml missing)."
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Start Docker and retry."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ docker-compose (or 'docker compose') not found."
    exit 1
fi

compose() {
    if command -v docker-compose &> /dev/null; then
        docker-compose "$@"
    else
        docker compose "$@"
    fi
}

echo "🔨 Building application..."
./scripts/build.sh

# Only Zookeeper + Kafka — avoids port 8080 conflict with local dashboard (compaction-app also binds 8080).
echo "🐳 Starting Kafka infrastructure (zookeeper + kafka)..."
compose up -d zookeeper kafka

echo "⏳ Waiting for Kafka on localhost:9092..."
timeout=90
while ! nc -z localhost 9092 2>/dev/null; do
    sleep 2
    timeout=$((timeout - 2))
    if [ "$timeout" -le 0 ]; then
        echo "❌ Timeout waiting for Kafka"
        compose down --remove-orphans 2>/dev/null || true
        exit 1
    fi
done
echo "✅ Kafka is ready!"

echo "🧪 Running tests..."
./scripts/test.sh

export PYTHONPATH="$ROOT"
echo "🌐 Starting web dashboard..."
venv/bin/python -m uvicorn src.web.dashboard_app:create_app --factory --host 0.0.0.0 --port 8080 &
WEB_PID=$!

echo "⏳ Waiting for dashboard to listen..."
sleep 5

echo "🚀 Starting main application..."
venv/bin/python src/main.py &
APP_PID=$!

echo ""
echo "🎉 Demo is running!"
echo "📊 Web Dashboard: http://localhost:8080"
echo "📊 API: http://localhost:8080/api/metrics"
echo ""
echo "Press Ctrl+C to stop the demo (stops app processes and Docker Kafka stack)"

cleanup_demo() {
    echo ""
    echo "🛑 Stopping demo..."
    kill "$WEB_PID" "$APP_PID" 2>/dev/null || true
    ( cd "$ROOT" && compose down --remove-orphans )
    echo "✅ Stopped."
}

trap 'cleanup_demo; exit 0' INT TERM

wait "$WEB_PID" "$APP_PID" 2>/dev/null || true
cleanup_demo
