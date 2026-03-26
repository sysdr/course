#!/bin/bash
# Direct execution of setup with error handling

set +e  # Don't exit on error initially

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting setup..."
echo "Working directory: $SCRIPT_DIR"

# Make setup script executable
chmod +x setup.sh

# Run setup script
bash setup.sh
SETUP_EXIT=$?

if [ $SETUP_EXIT -ne 0 ]; then
    echo "⚠️  Setup script exited with code $SETUP_EXIT"
    echo "Continuing with verification..."
fi

# Verify project was created
if [ -d "day150-cloud-deployment" ]; then
    echo "✅ Project directory created"
    cd day150-cloud-deployment
    
    # Verify key files
    if [ -f "start.sh" ] && [ -f "web/app.py" ]; then
        echo "✅ Key files exist"
        
        # Check for duplicates
        pkill -f "python.*web/app.py" 2>/dev/null || true
        
        # Make scripts executable
        chmod +x start.sh stop.sh 2>/dev/null || true
        
        echo ""
        echo "Setup verification complete!"
        echo "To start: cd day150-cloud-deployment && bash start.sh"
    else
        echo "❌ Key files missing"
        exit 1
    fi
else
    echo "❌ Project directory not created"
    exit 1
fi
