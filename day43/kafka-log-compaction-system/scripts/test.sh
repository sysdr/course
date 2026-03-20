#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "🧪 Running tests..."

if [ ! -x "venv/bin/pytest" ]; then
    echo "❌ venv or pytest missing. Run ./scripts/build.sh first."
    exit 1
fi

if [ ! -d "tests" ] || [ -z "$(find tests -name 'test_*.py' 2>/dev/null | head -1)" ]; then
    echo "❌ No tests found under tests/. Add test_*.py files or fix the tree."
    exit 1
fi

echo "🔍 Running tests with coverage..."
PYTHONPATH=. venv/bin/pytest tests/ -v --cov=src --cov-report=term-missing --cov-report=html

echo "✅ All tests passed!"
echo "📊 Coverage report: htmlcov/index.html"
