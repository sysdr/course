#!/bin/bash

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "🧹 Cleaning up project..."

stop_processes() {
    echo "Stopping running processes..."
    pkill -f "src\.main" 2>/dev/null || true
    pkill -f "uvicorn.*dashboard_app" 2>/dev/null || true
    pkill -f "python.*main\.py" 2>/dev/null || true
    if command -v lsof &> /dev/null; then
        lsof -ti:8080 | xargs kill -9 2>/dev/null || true
        lsof -ti:8081 | xargs kill -9 2>/dev/null || true
    fi
}

stop_docker() {
    echo "Stopping Docker containers..."
    if command -v docker-compose &> /dev/null; then
        docker-compose down --remove-orphans 2>/dev/null || true
    elif docker compose version &> /dev/null 2>&1; then
        docker compose down --remove-orphans 2>/dev/null || true
    fi
    docker ps -a --filter "name=kafka-log-compaction" -q 2>/dev/null | xargs docker rm -f 2>/dev/null || true
}

clean_python() {
    echo "Cleaning Python artifacts..."
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    find . -name "*.pyo" -delete 2>/dev/null || true
    rm -rf .pytest_cache 2>/dev/null || true
    rm -rf htmlcov 2>/dev/null || true
    rm -f .coverage 2>/dev/null || true
}

clean_venv() {
    echo "Removing virtual environment..."
    rm -rf venv 2>/dev/null || true
}

clean_generated() {
    echo "Cleaning generated files..."
    rm -rf logs/* 2>/dev/null || true
    rm -rf data/* 2>/dev/null || true
    find . -maxdepth 3 -name "*.tmp" -delete 2>/dev/null || true
}

usage() {
    echo "Usage: $0 [--stop | --all | --docker | --python | --logs]"
    echo "  (no args)  Same as --stop: stop app processes and docker-compose stack"
    echo "  --stop     Stop Python demo/dashboard and docker-compose (keeps venv, data)"
    echo "  --all      Stop everything, remove venv, clean caches and generated files"
    echo "  --docker   Stop Docker containers only"
    echo "  --python   Stop app processes, clean Python artifacts and venv"
    echo "  --logs     Clear logs/ and data/ contents only"
}

if [ $# -eq 0 ]; then
    set -- --stop
fi

case "$1" in
    --stop)
        stop_processes
        stop_docker
        ;;
    --all)
        stop_processes
        stop_docker
        clean_python
        clean_venv
        clean_generated
        ;;
    --docker)
        stop_docker
        ;;
    --python)
        stop_processes
        clean_python
        clean_venv
        ;;
    --logs)
        clean_generated
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
esac

echo "✅ Cleanup completed!"
echo "💡 Rebuild: ./scripts/build.sh  |  Run demo: ./run_demo.sh"
