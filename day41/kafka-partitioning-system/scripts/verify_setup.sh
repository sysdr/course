#!/bin/bash

# Quick verification script for individual components

echo "🔍 Verifying Kafka Partitioning System Setup"
echo "============================================="


# Check Python imports
echo "🐍 Testing Python imports..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

cd src
python -c "
try:
    print('Testing imports...')
    from config.kafka_config import config
    print('✅ Config import successful')
    
    from config.topic_manager import TopicManager
    print('✅ Topic manager import successful')
    
    from producer.log_producer import LogMessageProducer
    print('✅ Producer import successful')
    
    from consumer.log_consumer import LogConsumer
    print('✅ Consumer import successful')
    
    from monitoring.consumer_monitor import ConsumerGroupMonitor
    print('✅ Monitor import successful')
    
    print('✅ All imports successful!')
except Exception as e:
    print(f'❌ Import failed: {e}')
    exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Import test failed"
    cd ..
    exit 1
fi

echo ""
echo "🧪 Testing component functionality..."

# Test message generation
python -c "
try:
    from producer.log_producer import LogMessageProducer
    producer = LogMessageProducer('test')
    message = producer.generate_log_message(user_id='test_user')
    print(f'✅ Message generation works: {message[\"user_id\"]} -> {message[\"service\"]}')
    
    key = producer.get_partition_key(message)
    print(f'✅ Partition key generation works: {key}')
except Exception as e:
    print(f'❌ Producer test failed: {e}')
    exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Producer test failed"
    cd ..
    exit 1
fi

# Test consumer
python -c "
try:
    from consumer.log_consumer import LogConsumer
    consumer = LogConsumer('test-consumer')
    stats = consumer.get_stats()
    print(f'✅ Consumer initialization works: {stats[\"consumer_id\"]}')
except Exception as e:
    print(f'❌ Consumer test failed: {e}')
    exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Consumer test failed"
    cd ..
    exit 1
fi

# Test monitoring
python -c "
try:
    from monitoring.consumer_monitor import ConsumerGroupMonitor
    monitor = ConsumerGroupMonitor()
    print('✅ Monitor initialization works')
except Exception as e:
    print(f'❌ Monitor test failed: {e}')
    exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Monitor test failed"
    cd ..
    exit 1
fi

cd ..

echo ""
echo "✅ All component tests passed!"
echo ""
echo "🚀 System is ready! You can now:"
echo "   • Run './scripts/build_and_test.sh' for full testing with Kafka"
echo "   • Run './scripts/run_demo.sh' for interactive demo"
echo "   • Run 'cd src && python main.py --web' for web dashboard"
echo "   • Run 'cd src && python main.py --consumers 3 --rate 20' for CLI demo"
