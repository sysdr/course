#!/bin/bash

echo "🔍 Verifying Log Consumer Implementation"
echo "======================================"

# Check file structure
echo "📁 Checking project structure..."
files=(
    "src/consumers/log_consumer.py"
    "src/processors/log_processor.py"
    "src/consumers/consumer_manager.py"
    "src/monitoring/dashboard.py"
    "src/main.py"
    "tests/unit/test_log_consumer.py"
    "tests/unit/test_log_processor.py"
    "tests/integration/test_consumer_integration.py"
    "config/consumer_config.json"
    "requirements.txt"
    "Dockerfile"
    "docker-compose.yml"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (missing)"
    fi
done

# Check Python syntax
echo -e "\n🐍 Checking Python syntax..."
python -m py_compile src/consumers/log_consumer.py
python -m py_compile src/processors/log_processor.py
python -m py_compile src/consumers/consumer_manager.py
python -m py_compile src/monitoring/dashboard.py
python -m py_compile src/main.py

echo "✅ All Python files have valid syntax!"

# Check if Redis is accessible
echo -e "\n🔴 Testing Redis connection..."
if redis-cli ping &> /dev/null; then
    echo "✅ Redis is running and accessible"
else
    echo "⚠️  Redis is not running"
fi

# Test import functionality
echo -e "\n📦 Testing imports..."
python -c "
try:
    from src.consumers.log_consumer import LogConsumer, ConsumerConfig
    from src.processors.log_processor import LogProcessor
    from src.consumers.consumer_manager import ConsumerManager
    print('✅ All imports successful')
except ImportError as e:
    print(f'❌ Import error: {e}')
    exit(1)
"

echo -e "\n🎉 Verification complete!"
