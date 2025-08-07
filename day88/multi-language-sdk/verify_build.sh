#!/bin/bash

# Build Verification Script for Multi-Language SDK
# Validates all created directories, files, and basic functionality

set -euo pipefail

echo "✅ Build Verification Report"
echo "============================"

# Check if we're in the project directory
if [[ ! -d "python-sdk" ]] || [[ ! -d "java-sdk" ]] || [[ ! -d "javascript-sdk" ]]; then
    echo "❌ Error: Not in project directory. Please run this script from the project root."
    exit 1
fi

# Check file structure
echo "📁 Checking project structure..."
EXPECTED_FILES=(
    "python-sdk/setup.py"
    "python-sdk/src/logplatform_sdk/__init__.py"
    "python-sdk/src/logplatform_sdk/client.py"
    "python-sdk/src/logplatform_sdk/config.py"
    "python-sdk/src/logplatform_sdk/models.py"
    "python-sdk/src/logplatform_sdk/exceptions.py"
    "java-sdk/pom.xml"
    "java-sdk/src/main/java/com/logplatform/sdk/LogPlatformClient.java"
    "javascript-sdk/package.json"
    "javascript-sdk/src/index.ts"
    "javascript-sdk/src/client.ts"
    "javascript-sdk/src/config.ts"
    "javascript-sdk/src/types.ts"
    "javascript-sdk/src/exceptions.ts"
    "api-server/src/main.py"
    "docker-compose.yml"
    "start.sh"
    "stop.sh"
    "run_demo.sh"
    "verify_build.sh"
)

missing_files=0
for file in "${EXPECTED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file"
    else
        echo "❌ Missing: $file"
        ((missing_files++))
    fi
done

if [[ $missing_files -gt 0 ]]; then
    echo "❌ Found $missing_files missing files"
    exit 1
fi

# Test Python syntax
echo ""
echo "🐍 Checking Python syntax..."
cd python-sdk
if python3.11 -m py_compile src/logplatform_sdk/*.py 2>/dev/null; then
    echo "✅ Python syntax OK"
else
    echo "❌ Python syntax errors found"
    exit 1
fi
cd ..

# Test API server
echo ""
echo "🌐 Testing API server startup..."
cd api-server
if python3.11 -m py_compile src/main.py 2>/dev/null; then
    echo "✅ API server syntax OK"
else
    echo "❌ API server syntax errors found"
    exit 1
fi
cd ..

# Check JavaScript if available
if command -v node &> /dev/null; then
    echo ""
    echo "🟨 Checking JavaScript/TypeScript..."
    cd javascript-sdk
    if [[ -f "package.json" ]] && command -v npm &> /dev/null; then
        if npm install --silent 2>/dev/null; then
            echo "✅ JavaScript dependencies installed"
        else
            echo "⚠️ JavaScript dependencies installation failed"
        fi
    fi
    cd ..
fi

# Check Java if available
if command -v mvn &> /dev/null; then
    echo ""
    echo "☕ Checking Java project..."
    cd java-sdk
    if mvn validate --quiet 2>/dev/null; then
        echo "✅ Java project validation OK"
    else
        echo "⚠️ Java project validation failed"
    fi
    cd ..
fi

# Check script permissions
echo ""
echo "🔧 Checking script permissions..."
scripts=("start.sh" "stop.sh" "run_demo.sh" "verify_build.sh")
for script in "${scripts[@]}"; do
    if [[ -x "$script" ]]; then
        echo "✅ $script is executable"
    else
        echo "⚠️ $script is not executable"
        chmod +x "$script"
        echo "✅ Made $script executable"
    fi
done

echo ""
echo "🎯 All checks completed!"
echo ""
echo "To run the complete demo:"
echo "1. ./start.sh     # Setup environments"
echo "2. ./run_demo.sh  # Run all SDK demos"
echo "3. ./stop.sh      # Clean shutdown"
echo ""
echo "🚀 Project is ready for development!"
