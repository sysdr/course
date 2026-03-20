#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "🔨 Building Kafka Log Compaction System..."

if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found. Please install Python3 first."
    exit 1
fi

if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

echo "📦 Installing Python dependencies..."
venv/bin/pip install -U pip -q
venv/bin/pip install -r requirements.txt

echo "📁 Creating necessary directories..."
mkdir -p data logs

if command -v docker &> /dev/null; then
    echo "🐳 Docker found — use ./run_demo.sh after Kafka is up."
else
    echo "⚠️  Docker not found — Kafka must be available for ./run_demo.sh"
fi

echo "✅ Build successful!"
echo "🚀 Next: ./run_demo.sh  (full demo)  |  ./scripts/test.sh  (tests only)"
