# Day 22: Multi-Node Storage Cluster with File Replication

## Overview
This project implements a distributed log storage cluster with automatic file replication across multiple nodes. It demonstrates key concepts of distributed systems including:

- Multi-node storage architecture
- Asynchronous replication
- Health monitoring and failover
- Consensus mechanisms
- Load balancing

## Architecture
```
Client -> Cluster Manager -> Primary Node -> [Replication] -> Replica Nodes
```

## Quick Start

### 1. Start the Cluster
```bash
python scripts/start_cluster.py
```

### 2. Test Functionality
```bash
python scripts/test_cluster.py
```

### 3. View Dashboard
Open `web/cluster_dashboard.html` in your browser

### 4. Docker Deployment
```bash
cd docker
docker-compose up -d
```

## API Endpoints

### Health Check
```
GET http://localhost:5001/health
```

### Write Log
```
POST http://localhost:5001/write
Content-Type: application/json

{
  "message": "Log message",
  "level": "info",
  "source": "application"
}
```

### Read Log
```
GET http://localhost:5001/read/{filename}
```

### Node Statistics
```
GET http://localhost:5001/stats
```

## Configuration
Edit `src/config/cluster_config.py` to modify:
- Number of nodes
- Port assignments
- Storage paths
- Replication factor

## Testing
```bash
# Unit tests
python -m pytest tests/ -v

# Integration tests
python scripts/test_cluster.py

# Load testing
python -c "
import requests
import json
for i in range(100):
    requests.post('http://localhost:5001/write', 
                 json={'message': f'Load test {i}', 'level': 'info'})
"
```

## Monitoring
- Web Dashboard: `web/cluster_dashboard.html`
- Health endpoints: `http://localhost:500[1-3]/health`
- Statistics: `http://localhost:500[1-3]/stats`

## Success Criteria
✅ 3-node cluster starts successfully
✅ Primary node accepts writes
✅ Files replicated to 2+ nodes
✅ Cluster survives node failures
✅ Health monitoring detects issues
✅ Web dashboard shows real-time status

## Next Steps (Day 23)
- Implement partitioning strategies
- Add query performance optimizations
- Implement time-based and source-based partitioning
