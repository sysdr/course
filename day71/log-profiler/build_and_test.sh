#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
# shellcheck source=/dev/null
source "$SCRIPT_DIR/venv/bin/activate"

export PYTHONPATH="${SCRIPT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"
echo "🧪 Running unit tests..."
python -m pytest tests/test_profiler.py -v

echo "🎮 Running demonstration..."
python demo.py

echo "✅ Tests and demo finished. Start the dashboard with: ./start.sh"
