#!/bin/bash

echo "🎬 RabbitMQ Log Processing Demo"

# Setup
python3 -m message_queue.rabbitmq_setup

echo "📊 Publishing sample log messages..."
python3 -c "
from message_queue.queue_manager import QueueManager
import time

manager = QueueManager()
if manager.connect():
    messages = [
        ('logs.info.web', {'level': 'INFO', 'source': 'nginx', 'message': 'GET /api/users 200'}),
        ('logs.error.db', {'level': 'ERROR', 'source': 'postgres', 'message': 'Connection pool exhausted'}),
        ('logs.warning.app', {'level': 'WARNING', 'source': 'django', 'message': 'Slow query detected'}),
        ('logs.debug.cache', {'level': 'DEBUG', 'source': 'redis', 'message': 'Cache miss for key user:123'})
    ]
    
    for routing_key, message in messages:
        manager.publish_message(routing_key, message)
        print(f'📤 Published: {routing_key} -> {message[\"message\"]}')
        time.sleep(0.5)
    
    manager.close()
    print('✅ Demo messages published!')
"

echo "🏥 Final health check..."
python3 -m message_queue.health_checker

echo "🌐 Access RabbitMQ Management UI at: http://localhost:15672"
echo "👤 Username: guest, Password: guest"
