# Day 42: Exactly-Once Processing with Kafka

This project demonstrates exactly-once processing semantics in Apache Kafka for financial transaction processing.

## Features

- **Transactional Producers**: Idempotent message production with transaction support
- **Exactly-Once Consumers**: Guaranteed single processing of each message
- **Transaction Monitoring**: Real-time monitoring of processing guarantees
- **Web Dashboard**: Live visualization of transaction flow and system health
- **Database Integration**: Atomic processing with PostgreSQL

## Quick Start

```bash
# Build and test the system
./build_and_test.sh

# Run full demonstration
python scripts/demo.py

# Or start components individually
python -m src.main web         # Web dashboard at localhost:5000
python -m src.main consumer    # Start consumer
python -m src.main producer    # Start producer
```

## Architecture

The system demonstrates exactly-once processing through:

1. **Idempotent Producers** with unique transaction IDs
2. **Transactional Semantics** for atomic multi-partition writes  
3. **Manual Offset Management** tied to business logic completion
4. **Database Integration** for consistent state management

## Testing

Run the test suite:
```bash
python -m pytest tests/test_exactly_once.py -v
```

## Monitoring

Access the web dashboard at http://localhost:5000 to monitor:
- Transaction processing rates
- Account balances in real-time
- Exactly-once guarantee verification
- System health metrics

## Cleanup

```bash
docker-compose down -v
```
