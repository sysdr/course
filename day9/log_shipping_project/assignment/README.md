# Log Shipping Client - Assignment Solution

This is the enhanced implementation with resilience features, compression, and metrics.

## Features

### Resilient Shipper
- In-memory buffering for failed deliveries
- Disk-based persistence across restarts
- Exponential backoff for reconnection

### Enhanced Shipper
- Log compression with gzip
- Batch sending to reduce network overhead
- Heartbeat monitoring
- Comprehensive metrics collection

## Running the Project

### Install Dependencies
```bash
pip install -r requirements.txt
```

### Start the Enhanced Server
```bash
python enhanced_server.py --port 9000
```

### Run Resilient Client
```bash
python -m src.resilient_main --log-file sample_logs.txt --server-host localhost --server-port 9000
```

### Run Enhanced Client
```bash
python -m src.enhanced_main --log-file sample_logs.txt --server-host localhost --server-port 9000 --compress --batch-size 5 --metrics-interval 10
```

### Run Tests
```bash
pytest tests/ -v
```

### Using Docker
```bash
docker-compose up
```

## Testing Resilience

1. Start server and client
2. Stop server to test buffering
3. Add logs during server downtime
4. Restart server to see automatic reconnection

## Metrics

The enhanced shipper provides real-time metrics:
- Logs sent/failed
- Bytes sent
- Compression savings
- Connection statistics
- Buffer utilization
