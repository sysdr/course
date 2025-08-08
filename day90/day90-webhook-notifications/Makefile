.PHONY: help install start stop test clean build docker-build docker-run

# Default target
help:
	@echo "Available commands:"
	@echo "  install     - Install dependencies and setup environment"
	@echo "  start       - Start the application"
	@echo "  stop        - Stop the application"
	@echo "  test        - Run tests"
	@echo "  clean       - Clean up temporary files"
	@echo "  build       - Build frontend"
	@echo "  docker-build - Build Docker image"
	@echo "  docker-run  - Run with Docker Compose"

# Install dependencies
install:
	@echo "📦 Installing dependencies..."
	python3.11 -m venv venv
	. venv/bin/activate && pip install -r requirements.txt
	cd frontend && npm install

# Start the application
start:
	@echo "🚀 Starting application..."
	./start.sh

# Stop the application
stop:
	@echo "🛑 Stopping application..."
	./stop.sh

# Run tests
test:
	@echo "🧪 Running tests..."
	. venv/bin/activate && python -m pytest tests/ -v

# Clean up
clean:
	@echo "🧹 Cleaning up..."
	rm -rf src/__pycache__
	rm -rf .pytest_cache
	rm -rf frontend/build
	rm -rf frontend/node_modules
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete

# Build frontend
build:
	@echo "🏗️ Building frontend..."
	cd frontend && npm run build

# Docker commands
docker-build:
	@echo "🐳 Building Docker image..."
	docker build -t webhook-notifications .

docker-run:
	@echo "🐳 Running with Docker Compose..."
	docker-compose up -d

docker-stop:
	@echo "🐳 Stopping Docker containers..."
	docker-compose down

# Development helpers
dev-install:
	@echo "🔧 Installing development dependencies..."
	. venv/bin/activate && pip install pytest pytest-asyncio pytest-cov black flake8

format:
	@echo "🎨 Formatting code..."
	. venv/bin/activate && black src/ tests/

lint:
	@echo "🔍 Linting code..."
	. venv/bin/activate && flake8 src/ tests/

# Database and data management
reset-data:
	@echo "🗑️ Resetting demo data..."
	rm -f data/*.json

# Monitoring and logs
logs:
	@echo "📋 Showing logs..."
	tail -f logs/app.log

# Health check
health:
	@echo "🏥 Checking application health..."
	curl -f http://localhost:8000/api/v1/health || echo "❌ Application not responding"
