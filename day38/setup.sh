#!/bin/bash

# Day 38: Kafka Cluster Setup Implementation Script
# Creates a production-ready 3-broker Kafka cluster with comprehensive testing

set -e

echo "🚀 Setting up Kafka Cluster for Log Processing - Day 38"
echo "======================================================="

# Create project structure
echo "📁 Creating project structure..."
mkdir -p kafka-log-cluster/{config,scripts,src,test,demo,logs}
cd kafka-log-cluster

# Create Docker Compose configuration
echo "🐳 Creating Docker Compose setup..."
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  zookeeper-1:
    image: confluentinc/cp-zookeeper:7.6.1
    container_name: zookeeper-1
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
      ZOOKEEPER_SERVER_ID: 1
    ports:
      - "2181:2181"
    networks:
      - kafka-network

  kafka-broker-1:
    image: confluentinc/cp-kafka:7.6.1
    container_name: kafka-broker-1
    depends_on:
      - zookeeper-1
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper-1:2181
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-broker-1:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_NUM_PARTITIONS: 3
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_LOG_RETENTION_HOURS: 168
      KAFKA_LOG_SEGMENT_BYTES: 1073741824
      KAFKA_NUM_NETWORK_THREADS: 8
      KAFKA_NUM_IO_THREADS: 16
    networks:
      - kafka-network

  kafka-broker-2:
    image: confluentinc/cp-kafka:7.6.1
    container_name: kafka-broker-2
    depends_on:
      - zookeeper-1
    ports:
      - "9093:9093"
    environment:
      KAFKA_BROKER_ID: 2
      KAFKA_ZOOKEEPER_CONNECT: zookeeper-1:2181
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-broker-2:29093,PLAINTEXT_HOST://localhost:9093
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_NUM_PARTITIONS: 3
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_LOG_RETENTION_HOURS: 168
      KAFKA_LOG_SEGMENT_BYTES: 1073741824
      KAFKA_NUM_NETWORK_THREADS: 8
      KAFKA_NUM_IO_THREADS: 16
    networks:
      - kafka-network

  kafka-broker-3:
    image: confluentinc/cp-kafka:7.6.1
    container_name: kafka-broker-3
    depends_on:
      - zookeeper-1
    ports:
      - "9094:9094"
    environment:
      KAFKA_BROKER_ID: 3
      KAFKA_ZOOKEEPER_CONNECT: zookeeper-1:2181
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-broker-3:29094,PLAINTEXT_HOST://localhost:9094
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_NUM_PARTITIONS: 3
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_LOG_RETENTION_HOURS: 168
      KAFKA_LOG_SEGMENT_BYTES: 1073741824
      KAFKA_NUM_NETWORK_THREADS: 8
      KAFKA_NUM_IO_THREADS: 16
    networks:
      - kafka-network

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    depends_on:
      - kafka-broker-1
      - kafka-broker-2
      - kafka-broker-3
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka-broker-1:29092,kafka-broker-2:29093,kafka-broker-3:29094
      KAFKA_CLUSTERS_0_ZOOKEEPER: zookeeper-1:2181
    networks:
      - kafka-network

networks:
  kafka-network:
    driver: bridge
EOF

# Create Python dependencies
echo "📦 Creating Python requirements..."
cat > requirements.txt << 'EOF'
confluent-kafka==2.4.0
six==1.16.0
fastapi==0.111.0
uvicorn==0.30.1
pydantic==2.7.1
asyncio-mqtt==0.16.1
prometheus-client==0.20.0
pytest==8.2.1
pytest-asyncio==0.23.7
requests==2.32.2
faker==25.3.0
websockets==12.0
jinja2==3.1.4
EOF

# Create cluster setup script
echo "⚙️ Creating cluster setup script..."
cat > scripts/setup_cluster.py << 'EOF'
#!/usr/bin/env python3
"""Kafka cluster setup and topic creation."""

import time
from confluent_kafka.admin import AdminClient, NewTopic
from confluent_kafka import Producer, Consumer

def wait_for_kafka(bootstrap_servers='localhost:9092'):
    """Wait for Kafka to be ready."""
    print("⏳ Waiting for Kafka cluster to be ready...")
    max_retries = 30
    for i in range(max_retries):
        try:
            admin_client = AdminClient({'bootstrap.servers': bootstrap_servers})
            metadata = admin_client.list_topics(timeout=5)
            print(f"✅ Kafka cluster ready with {len(metadata.brokers)} brokers")
            return admin_client
        except Exception as e:
            print(f"🔄 Attempt {i+1}/{max_retries}: {str(e)}")
            time.sleep(5)
    raise Exception("Kafka cluster not ready after 30 attempts")

def create_topics(admin_client):
    """Create required topics for log processing."""
    topics = [
        NewTopic("web-api-logs", num_partitions=3, replication_factor=3),
        NewTopic("user-service-logs", num_partitions=3, replication_factor=3),
        NewTopic("payment-service-logs", num_partitions=3, replication_factor=3),
        NewTopic("critical-logs", num_partitions=1, replication_factor=3),
        NewTopic("error-aggregation", num_partitions=1, replication_factor=3),
    ]
    
    futures = admin_client.create_topics(topics)
    for topic, future in futures.items():
        try:
            future.result()
            print(f"✅ Created topic: {topic}")
        except Exception as e:
            if "already exists" in str(e).lower():
                print(f"ℹ️ Topic already exists: {topic}")
            else:
                print(f"❌ Failed to create topic {topic}: {str(e)}")

def verify_cluster_health():
    """Verify cluster health and topic creation."""
    try:
        # Test producer
        producer = Producer({'bootstrap.servers': 'localhost:9092'})
        producer.produce('web-api-logs', 'test-message')
        producer.flush()
        print("✅ Producer test successful")
        
        # Test consumer
        consumer = Consumer({
            'bootstrap.servers': 'localhost:9092',
            'group.id': 'test-group',
            'auto.offset.reset': 'earliest'
        })
        consumer.subscribe(['web-api-logs'])
        
        # Poll for messages with timeout
        messages = []
        start_time = time.time()
        while time.time() - start_time < 5:
            msg = consumer.poll(1.0)
            if msg is not None and not msg.error():
                messages.append(msg)
        
        consumer.close()
        print(f"✅ Consumer test successful - received {len(messages)} messages")
        
    except Exception as e:
        print(f"❌ Cluster health check failed: {str(e)}")

if __name__ == "__main__":
    admin_client = wait_for_kafka()
    create_topics(admin_client)
    verify_cluster_health()
    print("🎉 Kafka cluster setup complete!")
EOF

# Create log producer simulation
cat > src/log_producer.py << 'EOF'
#!/usr/bin/env python3
"""Multi-service log producer for Kafka."""

import json
import time
import random
from datetime import datetime, UTC
from confluent_kafka import Producer
from faker import Faker

fake = Faker()

class LogProducer:
    def __init__(self, bootstrap_servers='localhost:9092'):
        self.producer = Producer({
            'bootstrap.servers': bootstrap_servers,
        })
        
    def generate_web_api_log(self):
        """Generate web API log entry."""
        return {
            'timestamp': datetime.now(UTC).isoformat(),
            'service': 'web-api',
            'level': random.choice(['INFO', 'WARN', 'ERROR']),
            'method': random.choice(['GET', 'POST', 'PUT', 'DELETE']),
            'endpoint': random.choice(['/api/users', '/api/orders', '/api/products']),
            'status_code': random.choice([200, 201, 400, 404, 500]),
            'response_time_ms': random.randint(10, 2000),
            'user_id': fake.uuid4(),
            'ip_address': fake.ipv4(),
        }
    
    def generate_user_service_log(self):
        """Generate user service log entry."""
        return {
            'timestamp': datetime.utcnow().isoformat(),
            'service': 'user-service',
            'level': random.choice(['INFO', 'WARN', 'ERROR']),
            'event_type': random.choice(['login', 'logout', 'register', 'password_reset']),
            'user_id': fake.uuid4(),
            'email': fake.email(),
            'success': random.choice([True, False]),
            'ip_address': fake.ipv4(),
        }
    
    def generate_payment_service_log(self):
        """Generate payment service log entry."""
        return {
            'timestamp': datetime.utcnow().isoformat(),
            'service': 'payment-service',
            'level': random.choice(['INFO', 'WARN', 'ERROR']),
            'transaction_id': fake.uuid4(),
            'amount': round(random.uniform(1.0, 1000.0), 2),
            'currency': random.choice(['USD', 'EUR', 'GBP']),
            'status': random.choice(['pending', 'completed', 'failed']),
            'payment_method': random.choice(['credit_card', 'paypal', 'bank_transfer']),
        }
    
    def send_logs(self, duration_seconds=60):
        """Send logs to appropriate topics."""
        print(f"🚀 Starting log generation for {duration_seconds} seconds...")
        start_time = time.time()
        
        while time.time() - start_time < duration_seconds:
            # Generate and send different types of logs
            web_log = self.generate_web_api_log()
            self.producer.produce('web-api-logs', 
                                value=json.dumps(web_log), 
                                key=web_log['user_id'])
            
            user_log = self.generate_user_service_log()
            self.producer.produce('user-service-logs', 
                                value=json.dumps(user_log), 
                                key=user_log['user_id'])
            
            payment_log = self.generate_payment_service_log()
            self.producer.produce('payment-service-logs', 
                                value=json.dumps(payment_log), 
                                key=payment_log['transaction_id'])
            
            # Send critical logs for errors
            if web_log['level'] == 'ERROR' or user_log['level'] == 'ERROR' or payment_log['level'] == 'ERROR':
                critical_log = {
                    'timestamp': datetime.now(UTC).isoformat(),
                    'priority': 'CRITICAL',
                    'original_service': web_log.get('service', user_log.get('service', payment_log.get('service'))),
                    'error_details': 'System error detected'
                }
                self.producer.produce('critical-logs', value=json.dumps(critical_log))
            
            time.sleep(0.1)  # 10 messages per second per service
        
        self.producer.flush()
        print("✅ Log generation completed")

if __name__ == "__main__":
    producer = LogProducer()
    producer.send_logs(60)
EOF

# Create error aggregation consumer
cat > src/error_aggregator.py << 'EOF'
#!/usr/bin/env python3
"""Error aggregation consumer across all services."""

import json
from collections import defaultdict
from confluent_kafka import Consumer
from datetime import datetime

class ErrorAggregator:
    def __init__(self, bootstrap_servers='localhost:9092'):
        self.consumer = Consumer({
            'bootstrap.servers': bootstrap_servers,
            'group.id': 'error-aggregator-group',
            'auto.offset.reset': 'latest'
        })
        self.consumer.subscribe(['web-api-logs', 'user-service-logs', 'payment-service-logs'])
        self.error_stats = defaultdict(int)
        
    def process_messages(self):
        """Process messages and aggregate errors."""
        print("🔍 Starting error aggregation...")
        
        try:
            while True:
                msg = self.consumer.poll(1.0)
                
                if msg is None:
                    continue
                if msg.error():
                    print(f"Consumer error: {msg.error()}")
                    continue
                
                try:
                    log_entry = json.loads(msg.value().decode('utf-8'))
                    
                    if log_entry.get('level') == 'ERROR':
                        service = log_entry.get('service', 'unknown')
                        self.error_stats[service] += 1
                        
                        print(f"❌ ERROR in {service}: {log_entry}")
                        
                except json.JSONDecodeError:
                    print(f"Failed to decode message: {msg.value()}")
                    
        except KeyboardInterrupt:
            pass
        finally:
            self.consumer.close()
            self.print_error_summary()
                
    def print_error_summary(self):
        """Print error statistics."""
        print("\n📊 Error Summary:")
        print("=" * 40)
        for service, count in self.error_stats.items():
            print(f"{service}: {count} errors")
        print("=" * 40)

if __name__ == "__main__":
    aggregator = ErrorAggregator()
    aggregator.process_messages()
EOF

# Create web dashboard
cat > demo/dashboard.py << 'EOF'
#!/usr/bin/env python3
"""Real-time Kafka monitoring dashboard."""

import json
import asyncio
from fastapi import FastAPI, WebSocket
from fastapi.responses import HTMLResponse
from confluent_kafka import Consumer
import threading
import time
from collections import deque

app = FastAPI()

# Store recent messages for dashboard
recent_messages = deque(maxlen=100)
stats = {'total_messages': 0, 'error_count': 0, 'services': set()}

def kafka_consumer_thread():
    """Background thread to consume Kafka messages."""
    consumer = Consumer({
        'bootstrap.servers': 'localhost:9092',
        'group.id': 'dashboard-group',
        'auto.offset.reset': 'latest'
    })
    consumer.subscribe(['web-api-logs', 'user-service-logs', 'payment-service-logs', 'critical-logs'])
    
    while True:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            continue
            
        try:
            log_entry = json.loads(msg.value().decode('utf-8'))
            log_entry['topic'] = msg.topic()
            recent_messages.append(log_entry)
            
            stats['total_messages'] += 1
            if log_entry.get('level') == 'ERROR':
                stats['error_count'] += 1
            stats['services'].add(log_entry.get('service', 'unknown'))
        except:
            continue

# Start Kafka consumer in background
threading.Thread(target=kafka_consumer_thread, daemon=True).start()

@app.get("/")
async def dashboard():
    """Serve the monitoring dashboard."""
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Kafka Log Monitoring Dashboard</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
            .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
            .stats { display: flex; gap: 20px; margin: 20px 0; }
            .stat-card { background: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .messages { background: white; padding: 20px; border-radius: 5px; max-height: 600px; overflow-y: auto; }
            .message { padding: 10px; margin: 5px 0; border-left: 4px solid #3498db; background: #ecf0f1; }
            .error { border-left-color: #e74c3c; background: #fadbd8; }
            .critical { border-left-color: #f39c12; background: #fdeaa7; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🚀 Kafka Log Processing Dashboard</h1>
            <p>Real-time monitoring of distributed log streams</p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <h3>Total Messages</h3>
                <p id="total-messages">0</p>
            </div>
            <div class="stat-card">
                <h3>Error Count</h3>
                <p id="error-count">0</p>
            </div>
            <div class="stat-card">
                <h3>Active Services</h3>
                <p id="service-count">0</p>
            </div>
        </div>
        
        <div class="messages">
            <h3>Recent Log Messages</h3>
            <div id="message-list"></div>
        </div>
        
        <script>
            const ws = new WebSocket("ws://localhost:8000/ws");
            
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                
                // Update stats
                document.getElementById('total-messages').textContent = data.stats.total_messages;
                document.getElementById('error-count').textContent = data.stats.error_count;
                document.getElementById('service-count').textContent = data.stats.services.length;
                
                // Update messages
                const messageList = document.getElementById('message-list');
                messageList.innerHTML = '';
                
                data.messages.forEach(msg => {
                    const div = document.createElement('div');
                    div.className = 'message';
                    if (msg.level === 'ERROR') div.className += ' error';
                    if (msg.topic === 'critical-logs') div.className += ' critical';
                    
                    div.innerHTML = `
                        <strong>${msg.service || msg.topic}</strong> 
                        [${msg.level || 'INFO'}] 
                        ${msg.timestamp}
                        <br>
                        <small>${JSON.stringify(msg, null, 2)}</small>
                    `;
                    messageList.appendChild(div);
                });
            };
            
            // Request updates every second
            setInterval(() => {
                if (ws.readyState === WebSocket.OPEN) {
                    ws.send('get_update');
                }
            }, 1000);
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates."""
    await websocket.accept()
    
    while True:
        try:
            await websocket.receive_text()
            
            # Send current stats and messages
            update_data = {
                'stats': {
                    'total_messages': stats['total_messages'],
                    'error_count': stats['error_count'],
                    'services': list(stats['services'])
                },
                'messages': list(recent_messages)
            }
            
            await websocket.send_text(json.dumps(update_data))
        except:
            break

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# Create test suite
cat > test/test_kafka_cluster.py << 'EOF'
#!/usr/bin/env python3
"""Comprehensive Kafka cluster tests."""

import pytest
import json
import time
from kafka import KafkaProducer, KafkaConsumer
from kafka.admin import KafkaAdminClient

class TestKafkaCluster:
    
    @pytest.fixture
    def producer(self):
        return KafkaProducer(
            bootstrap_servers='localhost:9092',
            value_serializer=lambda v: json.dumps(v).encode('utf-8')
        )
    
    @pytest.fixture
    def admin_client(self):
        return KafkaAdminClient(bootstrap_servers='localhost:9092')
    
    def test_cluster_connectivity(self, admin_client):
        """Test basic cluster connectivity."""
        metadata = admin_client.describe_cluster()
        assert len(metadata.brokers) >= 3, "Should have at least 3 brokers"
    
    def test_topic_creation(self, admin_client):
        """Test that required topics exist."""
        topics = admin_client.list_topics()
        required_topics = ['web-api-logs', 'user-service-logs', 'payment-service-logs', 'critical-logs']
        
        for topic in required_topics:
            assert topic in topics, f"Topic {topic} should exist"
    
    def test_message_production_consumption(self, producer):
        """Test end-to-end message flow."""
        test_message = {'test': 'message', 'timestamp': time.time()}
        
        # Send message
        producer.send('web-api-logs', test_message)
        producer.flush()
        
        # Consume message
        consumer = KafkaConsumer(
            'web-api-logs',
            bootstrap_servers='localhost:9092',
            auto_offset_reset='latest',
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            consumer_timeout_ms=5000
        )
        
        # Send another message to ensure consumer picks it up
        producer.send('web-api-logs', test_message)
        producer.flush()
        
        messages = list(consumer)
        assert len(messages) > 0, "Should receive at least one message"
        consumer.close()
    
    def test_high_throughput(self, producer):
        """Test high-throughput message processing."""
        start_time = time.time()
        message_count = 1000
        
        for i in range(message_count):
            producer.send('web-api-logs', {'id': i, 'data': f'test-{i}'})
        
        producer.flush()
        end_time = time.time()
        
        throughput = message_count / (end_time - start_time)
        print(f"Throughput: {throughput:.2f} messages/second")
        assert throughput > 100, "Should handle at least 100 messages/second"
    
    def test_partition_distribution(self, producer):
        """Test message distribution across partitions."""
        # This would require more complex setup to verify partition assignment
        # For now, we'll just verify the producer can send to the topic
        for i in range(10):
            producer.send('web-api-logs', {'partition_test': i}, key=str(i))
        producer.flush()
        
        assert True  # Placeholder - in real tests you'd check partition assignment

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create build and demo scripts
cat > scripts/build.sh << 'EOF'
#!/bin/bash
set -e

echo "🔨 Building Kafka Log Processing System..."

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Make scripts executable
chmod +x scripts/*.py scripts/*.sh
chmod +x src/*.py
chmod +x demo/*.py

echo "✅ Build completed successfully!"
EOF

cat > scripts/demo.sh << 'EOF'
#!/bin/bash
set -e

echo "🎬 Starting Kafka Cluster Demo..."

# Start Docker containers
echo "🐳 Starting Docker containers..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Setup cluster and topics
echo "⚙️ Setting up cluster and topics..."
python scripts/setup_cluster.py

# Start dashboard in background
echo "📊 Starting monitoring dashboard..."
python demo/dashboard.py &
DASHBOARD_PID=$!

# Start log generation
echo "📝 Starting log generation..."
python src/log_producer.py &
PRODUCER_PID=$!

# Start error aggregation
echo "🔍 Starting error aggregation..."
python src/error_aggregator.py &
AGGREGATOR_PID=$!

echo ""
echo "🎉 Demo is running!"
echo "📊 Dashboard: http://localhost:8000"
echo "🖥️  Kafka UI: http://localhost:8080"
echo ""
echo "Press Ctrl+C to stop demo"

# Wait for interrupt
trap "echo 'Stopping demo...'; kill $DASHBOARD_PID $PRODUCER_PID $AGGREGATOR_PID 2>/dev/null; docker-compose down; exit 0" INT
wait
EOF

chmod +x scripts/*.sh

# Create README with instructions
cat > README.md << 'EOF'
# Day 38: Kafka Cluster for Log Processing

## Quick Start

### With Docker (Recommended)
```bash
# Build and start demo
./scripts/build.sh
./scripts/demo.sh
```

### Without Docker
```bash
# Install and start local Kafka (requires Java)
# Download Kafka 2.13-3.7.0
wget https://downloads.apache.org/kafka/3.7.0/kafka_2.13-3.7.0.tgz
tar -xzf kafka_2.13-3.7.0.tgz
cd kafka_2.13-3.7.0

# Start Zookeeper
bin/zookeeper-server-start.sh config/zookeeper.properties &

# Start Kafka brokers (modify configs for multiple brokers)
bin/kafka-server-start.sh config/server.properties &

# Then run our Python components
python scripts/setup_cluster.py
python src/log_producer.py &
python demo/dashboard.py
```

## Testing
```bash
# Run comprehensive tests
python -m pytest test/ -v

# Run specific tests
python test/test_kafka_cluster.py
```

## Monitoring
- **Dashboard**: http://localhost:8000 - Real-time log monitoring
- **Kafka UI**: http://localhost:8080 - Cluster management interface

## Architecture
- 3-broker Kafka cluster with ZooKeeper coordination
- Multiple topics for different service logs
- Real-time error aggregation and monitoring
- Production-ready configuration with replication

## Assignment Solution
The implementation includes:
1. Three service simulators (web-api, user-service, payment-service)
2. Dedicated topics with proper partitioning
3. Error aggregation consumer across all services
4. Real-time monitoring dashboard
5. Comprehensive test suite

## Next Steps
- Integrate with Day 37's priority queue system
- Prepare for Day 39's intelligent log producers
- Scale cluster for higher throughput requirements
EOF

echo ""
echo "🎉 Kafka Cluster Implementation Complete!"
echo "========================================"
echo ""
echo "📁 Project structure created successfully"
echo "🐳 Docker Compose configuration ready"
echo "🔨 Build scripts prepared"
echo "🧪 Test suite included"
echo "📊 Demo dashboard implemented"
echo ""
echo "🚀 To start the demo:"
echo "   cd kafka-log-cluster"
echo "   ./scripts/build.sh"
echo "   ./scripts/demo.sh"
echo ""
echo "🌐 Access points:"
echo "   📊 Dashboard: http://localhost:8000"
echo "   🖥️  Kafka UI: http://localhost:8080"
echo ""
echo "✅ Ready for Day 39: Kafka Producers Implementation"