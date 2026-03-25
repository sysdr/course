#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Create venv if missing (keep project isolated from system Python)
if [ ! -x "venv/bin/python" ]; then
  python3 -m venv venv
fi
source venv/bin/activate

echo "🔨 Building Real-Time Log Indexing System"
echo "========================================="

echo "📦 Installing dependencies..."
pip install --upgrade pip >/dev/null
pip install -r requirements.txt

echo "🧪 Running unit tests..."
python -m pytest tests/test_realtime_indexing.py -v

echo "🔧 Running integration tests..."
python -m pytest tests/test_integration.py -v

echo "✅ Build and test completed successfully!"
