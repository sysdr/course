#!/bin/bash
echo "=== Building and testing without Docker ==="

# Detect platform
PLATFORM=$(uname)
echo "Detected platform: $PLATFORM"

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install system dependencies based on platform
case "$PLATFORM" in
    "Linux")
        echo "Installing Linux system dependencies..."
        sudo apt-get update
        sudo apt-get install -y python3-dev gcc
        ;;
    "Darwin")
        echo "Installing macOS system dependencies..."
        # Check if Homebrew is installed
        if ! command -v brew &> /dev/null; then
            echo "Homebrew not found. Please install it first: https://brew.sh"
            exit 1
        fi
        brew install python3
        ;;
    "MINGW"*|"MSYS"*|"CYGWIN"*)
        echo "Windows detected. No additional system dependencies required."
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        exit 1
        ;;
esac

# Install dependencies
pip install -r requirements.txt

# Set PYTHONPATH
export PYTHONPATH=$PWD

# Run tests
python -m pytest tests/

echo "=== Build and test completed successfully ==="
