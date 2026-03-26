#!/bin/bash
# Master execution script - runs everything in sequence

cd "$(dirname "$0")"

echo "=========================================="
echo "Master Execution Script"
echo "=========================================="
echo ""

# Make scripts executable
chmod +x setup.sh verify_setup.sh run_all.sh 2>/dev/null || true

# Run setup
echo ">>> Running setup.sh..."
bash setup.sh

# Verify
echo ""
echo ">>> Verifying files..."
if [ -f "verify_setup.sh" ]; then
    bash verify_setup.sh
fi

echo ""
echo ">>> Next steps:"
echo "   1. cd day150-cloud-deployment"
echo "   2. bash start.sh"
echo "   3. Open http://localhost:5000"
echo "   4. Verify metrics show non-zero values"
