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

## Implementation Guide

### Project Structure
```
distributed-log-cluster/
├── src/
│   ├── storage/
│   │   ├── __init__.py
│   │   ├── storage_node.py          # Individual storage node (Flask API, write/read/replicate)
│   │   ├── replication_manager.py   # Async file replication to target nodes
│   │   └── cluster_manager.py       # Orchestrates nodes, health monitoring, primary writes
│   ├── network/
│   │   ├── __init__.py
│   │   └── communication.py         # Inter-node HTTP helpers (health, write, read, replicate)
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── health_check.py          # HealthChecker for node health monitoring
│   │   └── file_utils.py            # File operation utilities (read/write JSON, ensure dir)
│   └── config/
│       ├── __init__.py
│       └── cluster_config.py        # get_cluster_config(), DEFAULT_CONFIG (ports, nodes)
├── tests/
│   ├── test_storage_node.py         # Storage node unit tests
│   ├── test_replication.py           # Replication manager tests
│   └── test_cluster_integration.py  # Full cluster integration tests
├── docker/
│   ├── Dockerfile                   # Python 3.9, runs start_node.py (one node per container)
│   └── docker-compose.yml           # 3 services (node1, node2, node3) on ports 5001–5003
├── scripts/
│   ├── setup_cluster.py             # Start cluster with --nodes N --base-port P
│   ├── start_cluster.py             # Start full cluster (DEFAULT_CONFIG, all nodes in one process)
│   ├── start_node.py                # Start single node (env: NODE_ID, NODE_PORT, STORAGE_PATH)
│   ├── test_cluster.py              # HTTP tests: health, write, read, stats
│   └── load_test.py                 # Load test: --requests N --concurrent C --port P
├── web/
│   ├── cluster_dashboard.html
│   └── static/dashboard.js
├── benchmark_test.py                # Single- and multi-threaded write benchmarks
├── requirements.txt
├── setup.py
└── README.md
```

### Core Components

| Component | Role |
|-----------|------|
| **StorageNode** | Flask app per node: `/`, `/health`, `/write`, `/read/<path>`, `/replicate`, `/stats`. Writes logs to local storage with checksum; serves replication endpoint. |
| **ReplicationManager** | Given primary node and target nodes, replicates written files via HTTP POST to targets’ `/replicate`. Uses async (httpx) with sync wrapper for cluster_manager. |
| **ClusterManager** | Loads config, creates StorageNodes, sets up ReplicationManager, starts health-monitor thread (requests to each node’s `/health`), runs all nodes in threads. Writes go to primary; replication triggered after write. |
| **HealthChecker** (utils) | Optional: background thread that GETs `/health` for a nodes dict and updates `node.is_healthy`. ClusterManager currently does health checks inline. |
| **cluster_config** | `get_cluster_config(num_nodes, base_port)` and `DEFAULT_CONFIG` (3 nodes, ports 7001–7003 by default). |

### Environment Setup
```bash
cd distributed-log-cluster
python3 -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Running Locally
- **Full cluster (all nodes in one process, default ports 7001–7003):**
  ```bash
  python scripts/start_cluster.py
  ```
- **Cluster with custom node count and base port:**
  ```bash
  python scripts/setup_cluster.py --nodes 3 --base-port 5001
  ```
- **Single node (e.g. for debugging):**
  ```bash
  export NODE_ID=storage_node_1 NODE_PORT=5001 STORAGE_PATH=logs/node1
  python scripts/start_node.py
  ```
- **Browser:** Open `http://localhost:7001/` (or the base port you used). Use `http://localhost:7001/health` and `http://localhost:7001/stats` for JSON.

### Running with Docker
- **Build and start (one node per container on 5001–5003):**
  ```bash
  cd docker
  docker-compose build
  docker-compose up -d
  ```
- **Access:** `http://localhost:5001/`, `http://localhost:5002/`, `http://localhost:5003/` (or from Windows host use your WSL IP, e.g. `http://172.18.x.x:5001/`).
- **Stop:** `docker-compose down`

### Testing
```bash
# Unit tests (storage node + replication)
python -m pytest tests/test_storage_node.py tests/test_replication.py -v

# All tests (including cluster integration; ensure cluster ports are free)
python -m pytest tests/ -v

# Cluster functionality (cluster must be running)
python scripts/test_cluster.py

# Load test (cluster must be running; default primary port from DEFAULT_CONFIG)
python scripts/load_test.py --requests 100 --concurrent 5 --port 7001

# Benchmark (hits primary node)
python benchmark_test.py
```

### Web Dashboard
- Serve the web folder: `python -m http.server 8080 --directory web`
- Open `http://localhost:8080/cluster_dashboard.html` and point it at your node URLs (e.g. `http://localhost:7001`, 7002, 7003 for local cluster, or 5001–5003 for Docker).

### Troubleshooting
- **Connection refused:** Ensure the cluster is running (`start_cluster.py` or Docker). From Windows browser to WSL Docker, use the WSL IP (e.g. `http://172.18.x.x:5001`) instead of `localhost` if needed.
- **Port in use:** Change `base_port` in config or use `setup_cluster.py --base-port <port>`. For Docker, edit `docker-compose.yml` port mappings.
- **Not Found on `/`:** Rebuild Docker (`docker-compose build --no-cache`) so the image includes the root route.

## Quick Start

### 1. Start the Cluster (local: ports 7001–7003)
```bash
source venv/bin/activate
python scripts/start_cluster.py
```

### 2. Test Functionality
```bash
python scripts/test_cluster.py
```

### 3. View Dashboard
Serve `web/` and open `http://localhost:8080/cluster_dashboard.html` (see Implementation Guide).

### 4. Docker Deployment (ports 5001–5003)
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
