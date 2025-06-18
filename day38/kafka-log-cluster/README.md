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
