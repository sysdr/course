#!/bin/bash

# Development helper script
case "$1" in
    "setup")
        echo "🔧 Setting up development environment..."
        ./scripts/setup.sh
        ;;
    "test")
        echo "🧪 Running tests..."
        ./scripts/test.sh
        ;;
    "main")
        echo "🚀 Starting main app..."
        ./scripts/run_main.sh
        ;;
    "web")
        echo "🌐 Starting web dashboard..."
        ./scripts/run_web.sh
        ;;
    "clean")
        echo "🧹 Cleaning up..."
        ./scripts/cleanup.sh
        ;;
    "clean-all")
        echo "🧹 Full cleanup..."
        ./scripts/cleanup.sh --all
        ;;
    "docker-build")
        echo "🐳 Building Docker..."
        ./scripts/docker_build.sh
        ;;
    "docker-run")
        echo "🐳 Running Docker..."
        ./scripts/docker_run.sh
        ;;
    "docker-clean")
        echo "🐳 Cleaning Docker..."
        ./scripts/docker_cleanup.sh
        ;;
    *)
        echo "Development helper script"
        echo "Usage: $0 {setup|test|main|web|clean|clean-all|docker-build|docker-run|docker-clean}"
        echo ""
        echo "Available commands:"
        echo "  setup        - Setup Python environment"
        echo "  test         - Run tests"
        echo "  main         - Start main application"
        echo "  web          - Start web dashboard"
        echo "  clean        - Clean generated files"
        echo "  clean-all    - Clean everything including venv"
        echo "  docker-build - Build Docker containers"
        echo "  docker-run   - Run Docker deployment"
        echo "  docker-clean - Clean Docker containers"
        ;;
esac
