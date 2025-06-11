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
