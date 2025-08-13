#!/bin/bash

echo "🛑 Stopping Advanced Log Search System"

# Kill any running Python processes for this project
pkill -f "python.*main.py" || true

# Deactivate virtual environment if active
if [[ "$VIRTUAL_ENV" != "" ]]; then
    deactivate
fi

echo "✅ System stopped"
