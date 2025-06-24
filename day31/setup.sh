#!/bin/bash

# Day 31: RabbitMQ Setup for Log Message Distribution
# Comprehensive Implementation Script

set -e  # Exit on any error

echo "🚀 Setting up RabbitMQ for Log Message Distribution..."

# Create project structure
echo "📁 Creating project structure..."
mkdir -p log-processing-system/{message_queue,config,tests,scripts}
cd log-processing-system

# Create requirements.txt
echo "📝 Creating requirements.txt..."
cat > requirements.txt << 'EOF'
pika==1.3.2
pyyaml==6.0.1
pytest==7.4.4
requests==2.31.0
colorama==0.4.6
EOF

# Create RabbitMQ configuration
echo "⚙️ Creating RabbitMQ configuration..."
cat > config/rabbitmq_config.yaml << 'EOF'
rabbitmq:
  host: localhost
  port: 5672
  username: guest
  password: guest
  virtual_host: /
  
queues:
  log_processing:
    name: log_messages
    durable: true
    auto_delete: false
  error_logs:
    name: error_messages
    durable: true
    auto_delete: false
  debug_logs:
    name: debug_messages
    durable: true
    auto_delete: false

exchanges:
  log_exchange:
    name: logs
    type: topic
    durable: true
EOF

# Create RabbitMQ setup module
echo "🔧 Creating RabbitMQ setup module..."
cat > message_queue/rabbitmq_setup.py << 'EOF'
"""
RabbitMQ setup and configuration for log processing system.
"""
import pika
import yaml
import logging
from typing import Dict, Any
import time

class RabbitMQSetup:
    def __init__(self, config_path: str = 'config/rabbitmq_config.yaml'):
        self.config = self._load_config(config_path)
        self.connection = None
        self.channel = None
        
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load RabbitMQ configuration from YAML file."""
        try:
            with open(config_path, 'r') as file:
                return yaml.safe_load(file)
        except FileNotFoundError:
            logging.error(f"Config file not found: {config_path}")
            raise
            
    def connect(self, max_retries: int = 5) -> bool:
        """Establish connection to RabbitMQ with retry logic."""
        rabbitmq_config = self.config['rabbitmq']
        
        for attempt in range(max_retries):
            try:
                credentials = pika.PlainCredentials(
                    rabbitmq_config['username'],
                    rabbitmq_config['password']
                )
                
                parameters = pika.ConnectionParameters(
                    host=rabbitmq_config['host'],
                    port=rabbitmq_config['port'],
                    virtual_host=rabbitmq_config['virtual_host'],
                    credentials=credentials,
                    heartbeat=600,
                    blocked_connection_timeout=300
                )
                
                self.connection = pika.BlockingConnection(parameters)
                self.channel = self.connection.channel()
                
                logging.info("Successfully connected to RabbitMQ")
                return True
                
            except pika.exceptions.AMQPConnectionError as e:
                logging.warning(f"Connection attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
                
        logging.error("Failed to connect to RabbitMQ after all retries")
        return False
        
    def setup_exchanges(self):
        """Create and configure exchanges."""
        exchanges = self.config['exchanges']
        
        for exchange_key, exchange_config in exchanges.items():
            self.channel.exchange_declare(
                exchange=exchange_config['name'],
                exchange_type=exchange_config['type'],
                durable=exchange_config['durable']
            )
            logging.info(f"Created exchange: {exchange_config['name']}")
            
    def setup_queues(self):
        """Create and configure queues with bindings."""
        queues = self.config['queues']
        exchange_name = self.config['exchanges']['log_exchange']['name']
        
        # Queue configurations with routing keys
        queue_bindings = {
            'log_messages': ['logs.info.*', 'logs.warning.*'],
            'error_messages': ['logs.error.*', 'logs.critical.*'],
            'debug_messages': ['logs.debug.*']
        }
        
        for queue_key, queue_config in queues.items():
            queue_name = queue_config['name']
            
            # Declare queue
            self.channel.queue_declare(
                queue=queue_name,
                durable=queue_config['durable'],
                auto_delete=queue_config['auto_delete']
            )
            
            # Bind queue to exchange with routing keys
            if queue_name in queue_bindings:
                for routing_key in queue_bindings[queue_name]:
                    self.channel.queue_bind(
                        exchange=exchange_name,
                        queue=queue_name,
                        routing_key=routing_key
                    )
                    
            logging.info(f"Created and bound queue: {queue_name}")
            
    def close_connection(self):
        """Close RabbitMQ connection."""
        if self.connection and not self.connection.is_closed:
            self.connection.close()
            logging.info("RabbitMQ connection closed")

def main():
    """Main setup function."""
    logging.basicConfig(level=logging.INFO)
    
    setup = RabbitMQSetup()
    
    if setup.connect():
        try:
            setup.setup_exchanges()
            setup.setup_queues()
            print("✅ RabbitMQ setup completed successfully!")
            print("🌐 Management UI available at: http://localhost:15672")
            print("👤 Default credentials: guest/guest")
        finally:
            setup.close_connection()
    else:
        print("❌ Failed to setup RabbitMQ")
        return False
        
    return True

if __name__ == "__main__":
    main()
EOF

# Create queue manager
echo "📊 Creating queue manager..."
cat > message_queue/queue_manager.py << 'EOF'
"""
Queue management utilities for log processing system.
"""
import pika
import json
import logging
from datetime import datetime
from typing import Dict, Any, Optional
from message_queue.rabbitmq_setup import RabbitMQSetup

class QueueManager:
    def __init__(self, config_path: str = 'config/rabbitmq_config.yaml'):
        self.setup = RabbitMQSetup(config_path)
        self.connection = None
        self.channel = None
        
    def connect(self) -> bool:
        """Connect to RabbitMQ."""
        if self.setup.connect():
            self.connection = self.setup.connection
            self.channel = self.setup.channel
            return True
        return False
        
    def publish_message(self, routing_key: str, message: Dict[str, Any]) -> bool:
        """Publish a message to the exchange."""
        try:
            exchange_name = self.setup.config['exchanges']['log_exchange']['name']
            
            # Add metadata to message
            enriched_message = {
                'timestamp': datetime.utcnow().isoformat(),
                'routing_key': routing_key,
                'data': message
            }
            
            self.channel.basic_publish(
                exchange=exchange_name,
                routing_key=routing_key,
                body=json.dumps(enriched_message),
                properties=pika.BasicProperties(
                    delivery_mode=2,  # Make message persistent
                    content_type='application/json'
                )
            )
            
            logging.info(f"Published message with routing key: {routing_key}")
            return True
            
        except Exception as e:
            logging.error(f"Failed to publish message: {e}")
            return False
            
    def get_queue_info(self, queue_name: str) -> Optional[Dict[str, Any]]:
        """Get information about a specific queue."""
        try:
            method = self.channel.queue_declare(queue=queue_name, passive=True)
            return {
                'queue_name': queue_name,
                'message_count': method.method.message_count,
                'consumer_count': method.method.consumer_count
            }
        except Exception as e:
            logging.error(f"Failed to get queue info: {e}")
            return None
            
    def purge_queue(self, queue_name: str) -> bool:
        """Remove all messages from a queue."""
        try:
            self.channel.queue_purge(queue=queue_name)
            logging.info(f"Purged queue: {queue_name}")
            return True
        except Exception as e:
            logging.error(f"Failed to purge queue: {e}")
            return False
            
    def close(self):
        """Close connection."""
        if self.setup:
            self.setup.close_connection()

def main():
    """Demo queue operations."""
    logging.basicConfig(level=logging.INFO)
    
    manager = QueueManager()
    
    if not manager.connect():
        print("❌ Failed to connect to RabbitMQ")
        return
        
    try:
        # Publish test messages
        test_messages = [
            ('logs.info.web', {'level': 'INFO', 'source': 'web-server', 'message': 'User login successful'}),
            ('logs.error.db', {'level': 'ERROR', 'source': 'database', 'message': 'Connection timeout'}),
            ('logs.debug.api', {'level': 'DEBUG', 'source': 'api', 'message': 'Request processed'})
        ]
        
        for routing_key, message in test_messages:
            manager.publish_message(routing_key, message)
            
        # Check queue status
        queues = ['log_messages', 'error_messages', 'debug_messages']
        for queue in queues:
            info = manager.get_queue_info(queue)
            if info:
                print(f"📊 Queue {queue}: {info['message_count']} messages, {info['consumer_count']} consumers")
                
    finally:
        manager.close()

if __name__ == "__main__":
    main()
EOF

# Create health checker
echo "🏥 Creating health checker..."
cat > message_queue/health_checker.py << 'EOF'
"""
Health monitoring for RabbitMQ and queue status.
"""
import pika
import requests
import logging
from typing import Dict, Any, List
from message_queue.rabbitmq_setup import RabbitMQSetup

class HealthChecker:
    def __init__(self, config_path: str = 'config/rabbitmq_config.yaml'):
        self.setup = RabbitMQSetup(config_path)
        self.management_url = "http://localhost:15672/api"
        
    def check_connection(self) -> Dict[str, Any]:
        """Check if RabbitMQ connection is healthy."""
        try:
            if self.setup.connect():
                self.setup.close_connection()
                return {'status': 'healthy', 'message': 'Connection successful'}
            else:
                return {'status': 'unhealthy', 'message': 'Connection failed'}
        except Exception as e:
            return {'status': 'unhealthy', 'message': str(e)}
            
    def check_management_api(self) -> Dict[str, Any]:
        """Check RabbitMQ management API availability."""
        try:
            response = requests.get(
                f"{self.management_url}/overview",
                auth=('guest', 'guest'),
                timeout=5
            )
            
            if response.status_code == 200:
                data = response.json()
                return {
                    'status': 'healthy',
                    'version': data.get('rabbitmq_version', 'unknown'),
                    'node': data.get('node', 'unknown')
                }
            else:
                return {'status': 'unhealthy', 'message': f'API returned {response.status_code}'}
                
        except requests.exceptions.RequestException as e:
            return {'status': 'unhealthy', 'message': str(e)}
            
    def check_queues(self) -> List[Dict[str, Any]]:
        """Check status of all configured queues."""
        queue_status = []
        
        try:
            response = requests.get(
                f"{self.management_url}/queues",
                auth=('guest', 'guest'),
                timeout=5
            )
            
            if response.status_code == 200:
                queues = response.json()
                
                configured_queues = self.setup.config['queues']
                for queue_key, queue_config in configured_queues.items():
                    queue_name = queue_config['name']
                    
                    # Find queue in API response
                    queue_data = next((q for q in queues if q['name'] == queue_name), None)
                    
                    if queue_data:
                        queue_status.append({
                            'name': queue_name,
                            'status': 'healthy',
                            'messages': queue_data.get('messages', 0),
                            'consumers': queue_data.get('consumers', 0),
                            'memory': queue_data.get('memory', 0)
                        })
                    else:
                        queue_status.append({
                            'name': queue_name,
                            'status': 'missing',
                            'message': 'Queue not found'
                        })
                        
        except Exception as e:
            logging.error(f"Failed to check queues: {e}")
            
        return queue_status
        
    def generate_health_report(self) -> Dict[str, Any]:
        """Generate comprehensive health report."""
        report = {
            'timestamp': None,
            'connection': self.check_connection(),
            'management_api': self.check_management_api(),
            'queues': self.check_queues()
        }
        
        # Determine overall health
        overall_healthy = (
            report['connection']['status'] == 'healthy' and
            report['management_api']['status'] == 'healthy' and
            all(q['status'] == 'healthy' for q in report['queues'])
        )
        
        report['overall_status'] = 'healthy' if overall_healthy else 'unhealthy'
        
        return report
        
def main():
    """Generate and display health report."""
    checker = HealthChecker()
    report = checker.generate_health_report()
    
    print("🏥 RabbitMQ Health Report")
    print("=" * 40)
    print(f"Overall Status: {'✅' if report['overall_status'] == 'healthy' else '❌'} {report['overall_status'].upper()}")
    print()
    
    print("Connection:", "✅" if report['connection']['status'] == 'healthy' else '❌', report['connection']['message'])
    
    if report['management_api']['status'] == 'healthy':
        print(f"Management API: ✅ Running (Version: {report['management_api']['version']})")
    else:
        print("Management API: ❌", report['management_api']['message'])
        
    print("\nQueues:")
    for queue in report['queues']:
        status_icon = "✅" if queue['status'] == 'healthy' else "❌"
        if queue['status'] == 'healthy':
            print(f"  {status_icon} {queue['name']}: {queue['messages']} messages, {queue['consumers']} consumers")
        else:
            print(f"  {status_icon} {queue['name']}: {queue.get('message', 'Unknown error')}")

if __name__ == "__main__":
    main()
EOF

# Create __init__.py files
echo "📦 Creating package files..."
touch message_queue/__init__.py

# Create test file
echo "🧪 Creating test file..."
cat > tests/test_message_queue.py << 'EOF'
"""
Integration tests for RabbitMQ message queue setup.
"""
import pytest
import time
import json
from message_queue.rabbitmq_setup import RabbitMQSetup
from message_queue.queue_manager import QueueManager
from message_queue.health_checker import HealthChecker

class TestRabbitMQSetup:
    def test_connection(self):
        """Test RabbitMQ connection."""
        setup = RabbitMQSetup()
        assert setup.connect(), "Should connect to RabbitMQ"
        setup.close_connection()
        
    def test_queue_creation(self):
        """Test queue and exchange creation."""
        setup = RabbitMQSetup()
        assert setup.connect(), "Should connect to RabbitMQ"
        
        try:
            setup.setup_exchanges()
            setup.setup_queues()
            
            # Verify queues exist
            queues = ['log_messages', 'error_messages', 'debug_messages']
            for queue_name in queues:
                method = setup.channel.queue_declare(queue=queue_name, passive=True)
                assert method.method.message_count >= 0
                
        finally:
            setup.close_connection()
            
class TestQueueManager:
    def test_message_publishing(self):
        """Test message publishing and retrieval."""
        manager = QueueManager()
        assert manager.connect(), "Should connect to RabbitMQ"
        
        try:
            # Publish test message
            test_message = {'test': 'data', 'timestamp': time.time()}
            assert manager.publish_message('logs.info.test', test_message)
            
            # Check queue info
            info = manager.get_queue_info('log_messages')
            assert info is not None
            assert info['message_count'] >= 0
            
        finally:
            manager.close()
            
class TestHealthChecker:
    def test_health_check(self):
        """Test health monitoring."""
        checker = HealthChecker()
        
        # Test connection check
        connection_status = checker.check_connection()
        assert connection_status['status'] in ['healthy', 'unhealthy']
        
        # Test health report generation
        report = checker.generate_health_report()
        assert 'overall_status' in report
        assert 'connection' in report
        assert 'queues' in report
        
if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create Docker setup
echo "🐳 Creating Docker setup..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  rabbitmq:
    image: rabbitmq:3.12-management
    container_name: log-rabbitmq
    hostname: rabbitmq
    ports:
      - "5672:5672"      # AMQP port
      - "15672:15672"    # Management UI port
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  rabbitmq_data:
EOF

# Create build script
echo "🔨 Creating build script..."
cat > scripts/build.sh << 'EOF'
#!/bin/bash

echo "🔨 Building Log Processing System - RabbitMQ Module"

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Verify installation
echo "✅ Verifying installations..."
python -c "import pika; print(f'Pika version: {pika.__version__}')"
python -c "import yaml; print('YAML support: OK')"

echo "🎯 Build completed successfully!"
EOF

# Create test script
echo "🧪 Creating test script..."
cat > scripts/test.sh << 'EOF'
#!/bin/bash

echo "🧪 Running RabbitMQ Tests"

# Wait for RabbitMQ to be ready
echo "⏳ Waiting for RabbitMQ to be ready..."
timeout=60
elapsed=0

while ! curl -s -u guest:guest http://localhost:15672/api/overview > /dev/null 2>&1; do
    if [ $elapsed -ge $timeout ]; then
        echo "❌ RabbitMQ did not become ready within $timeout seconds"
        exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo -n "."
done

echo " ✅ RabbitMQ is ready!"

# Run setup
echo "🔧 Running RabbitMQ setup..."
python -m message_queue.rabbitmq_setup

# Run health check
echo "🏥 Running health check..."
python -m message_queue.health_checker

# Run queue manager demo
echo "📊 Running queue manager demo..."
python -m message_queue.queue_manager

# Run pytest
echo "🧪 Running integration tests..."
python -m pytest tests/ -v

echo "✅ All tests completed!"
EOF

# Create demo script
echo "🎬 Creating demo script..."
cat > scripts/demo.sh << 'EOF'
#!/bin/bash

echo "🎬 RabbitMQ Log Processing Demo"

# Setup
python -m message_queue.rabbitmq_setup

echo "📊 Publishing sample log messages..."
python -c "
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
python -m message_queue.health_checker

echo "🌐 Access RabbitMQ Management UI at: http://localhost:15672"
echo "👤 Username: guest, Password: guest"
EOF

# Make scripts executable
chmod +x scripts/*.sh

# Create main execution script
echo "🎯 Creating main execution script..."
cat > run_setup.py << 'EOF'
#!/usr/bin/env python3
"""
Main execution script for RabbitMQ setup demonstration.
"""
import subprocess
import sys
import time
import os
from colorama import init, Fore, Style

init()  # Initialize colorama

def run_command(command, description):
    """Run a command with colored output."""
    print(f"\n{Fore.CYAN}🔄 {description}{Style.RESET_ALL}")
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"{Fore.GREEN}✅ {description} completed successfully{Style.RESET_ALL}")
        if result.stdout:
            print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"{Fore.RED}❌ {description} failed{Style.RESET_ALL}")
        if e.stdout:
            print(e.stdout)
        if e.stderr:
            print(e.stderr)
        return False

def main():
    """Main execution flow."""
    print(f"{Fore.MAGENTA}🚀 RabbitMQ Log Processing Setup{Style.RESET_ALL}")
    print("=" * 50)
    
    # Check if we're using Docker
    use_docker = len(sys.argv) > 1 and sys.argv[1] == '--docker'
    
    if use_docker:
        print(f"{Fore.YELLOW}🐳 Using Docker setup{Style.RESET_ALL}")
        
        # Start RabbitMQ with Docker
        if not run_command("docker-compose up -d rabbitmq", "Starting RabbitMQ with Docker"):
            return False
            
        # Wait for RabbitMQ to be ready
        print(f"{Fore.YELLOW}⏳ Waiting for RabbitMQ to start...{Style.RESET_ALL}")
        time.sleep(10)
        
    else:
        print(f"{Fore.YELLOW}🖥️ Using native setup (ensure RabbitMQ is installed and running){Style.RESET_ALL}")
    
    # Build and test
    steps = [
        ("bash scripts/build.sh", "Building project"),
        ("bash scripts/test.sh", "Running tests and demos"),
        ("bash scripts/demo.sh", "Running final demonstration")
    ]
    
    for command, description in steps:
        if not run_command(command, description):
            print(f"{Fore.RED}🛑 Setup failed at: {description}{Style.RESET_ALL}")
            return False
    
    # Final success message
    print(f"\n{Fore.GREEN}🎉 RabbitMQ setup completed successfully!{Style.RESET_ALL}")
    print(f"{Fore.CYAN}📊 Management UI: http://localhost:15672{Style.RESET_ALL}")
    print(f"{Fore.CYAN}👤 Credentials: guest/guest{Style.RESET_ALL}")
    
    if use_docker:
        print(f"\n{Fore.YELLOW}🐳 To stop Docker services: docker-compose down{Style.RESET_ALL}")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOF

# Create README
echo "📖 Creating README..."
cat > README.md << 'EOF'
# Day 31: RabbitMQ Setup for Log Message Distribution

## Quick Start

### Option 1: Docker Setup (Recommended)
```bash
python run_setup.py --docker
```

### Option 2: Native Setup
1. Install RabbitMQ: `brew install rabbitmq` (macOS) or `sudo apt install rabbitmq-server` (Ubuntu)
2. Start RabbitMQ: `sudo systemctl start rabbitmq-server`
3. Enable management plugin: `sudo rabbitmq-plugins enable rabbitmq_management`
4. Run setup: `python run_setup.py`

## Manual Build & Test

```bash
# Install dependencies
pip install -r requirements.txt

# Build
bash scripts/build.sh

# Test
bash scripts/test.sh

# Demo
bash scripts/demo.sh
```

## Verification

1. **Management UI**: http://localhost:15672 (guest/guest)
2. **Health Check**: `python -m message_queue.health_checker`
3. **Queue Status**: Check UI for message counts in log_messages, error_messages, debug_messages queues

## File Structure
```
log-processing-system/
├── message_queue/          # Core RabbitMQ modules
├── config/                 # Configuration files
├── tests/                  # Integration tests
├── scripts/                # Build and test scripts
└── docker-compose.yml      # Docker setup
```

## Success Criteria
- ✅ RabbitMQ server running
- ✅ Exchanges and queues created
- ✅ Messages routed correctly by log level
- ✅ Management UI accessible
- ✅ Health monitoring functional
EOF

echo "📊 Creating performance verification script..."
cat > scripts/verify_performance.py << 'EOF'
#!/usr/bin/env python3
"""
Performance verification for RabbitMQ setup.
"""
import time
import statistics
from message_queue.queue_manager import QueueManager

def performance_test():
    """Run basic performance verification."""
    print("🚀 Running RabbitMQ Performance Verification")
    
    manager = QueueManager()
    if not manager.connect():
        print("❌ Failed to connect")
        return
        
    try:
        # Publish 100 messages and measure time
        messages = 100
        start_time = time.time()
        
        for i in range(messages):
            message = {
                'id': i,
                'level': 'INFO',
                'source': 'performance_test',
                'message': f'Test message {i}'
            }
            manager.publish_message('logs.info.perf', message)
            
        end_time = time.time()
        duration = end_time - start_time
        throughput = messages / duration
        
        print(f"📊 Performance Results:")
        print(f"   Messages: {messages}")
        print(f"   Duration: {duration:.2f}s")
        print(f"   Throughput: {throughput:.0f} messages/second")
        
        # Check queue status
        info = manager.get_queue_info('log_messages')
        if info:
            print(f"   Queue depth: {info['message_count']} messages")
            
        if throughput > 100:
            print("✅ Performance verification PASSED")
        else:
            print("⚠️ Performance below expected threshold")
            
    finally:
        manager.close()

if __name__ == "__main__":
    performance_test()
EOF

chmod +x scripts/verify_performance.py run_setup.py

echo "✅ Project setup completed!"
echo ""
echo "🚀 To get started:"
echo "   For Docker: python run_setup.py --docker"
echo "   For Native: python run_setup.py"
echo ""
echo "📊 Management UI will be available at: http://localhost:15672"
echo "👤 Default credentials: guest/guest"