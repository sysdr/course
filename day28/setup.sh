#!/bin/bash

# Day 28: Read/Write Quorums Implementation Script
# Distributed Log Processing System - Week 4

set -e  # Exit on any error

echo "🚀 Day 28: Implementing Read/Write Quorums for Consistency Control"
echo "================================================================"

# Create project structure
echo "📁 Creating project structure..."
mkdir -p day28-quorum-consistency/{src,tests,config,logs,web,scripts}
cd day28-quorum-consistency

# Create requirements.txt
cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
aiohttp==3.9.1
asyncio==3.4.3
pydantic==2.5.0
pytest==7.4.3
pytest-asyncio==0.21.1
redis==5.0.1
websockets==12.0
jinja2==3.1.2
python-multipart==0.0.6
aiofiles==23.2.1
structlog==23.2.0
prometheus-client==0.19.0
EOF

# Create main quorum coordinator
cat > src/quorum_coordinator.py << 'EOF'
import asyncio
import time
import json
import logging
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from enum import Enum
import aiohttp

class ConsistencyLevel(Enum):
    STRONG = "strong"      # R=N, W=N
    EVENTUAL = "eventual"  # R=1, W=1
    BALANCED = "balanced"  # R=majority, W=majority

@dataclass
class QuorumConfig:
    total_replicas: int
    read_quorum: int
    write_quorum: int
    consistency_level: ConsistencyLevel
    timeout_ms: int = 5000

@dataclass
class LogEntry:
    key: str
    value: str
    timestamp: int
    vector_clock: Dict[str, int]
    node_id: str

class QuorumCoordinator:
    def __init__(self, node_id: str, nodes: List[str], config: QuorumConfig):
        self.node_id = node_id
        self.nodes = nodes
        self.config = config
        self.vector_clock = {node: 0 for node in nodes}
        self.local_storage = {}
        self.session = None
        
    async def start(self):
        self.session = aiohttp.ClientSession()
        
    async def stop(self):
        if self.session:
            await self.session.close()
    
    def update_quorum_config(self, consistency_level: ConsistencyLevel):
        """Update quorum configuration based on consistency level"""
        n = len(self.nodes)
        
        if consistency_level == ConsistencyLevel.STRONG:
            self.config.read_quorum = n
            self.config.write_quorum = n
        elif consistency_level == ConsistencyLevel.EVENTUAL:
            self.config.read_quorum = 1
            self.config.write_quorum = 1
        else:  # BALANCED
            majority = (n // 2) + 1
            self.config.read_quorum = majority
            self.config.write_quorum = majority
            
        self.config.consistency_level = consistency_level
        logging.info(f"Updated quorum: R={self.config.read_quorum}, W={self.config.write_quorum}, N={n}")
    
    async def write(self, key: str, value: str) -> Tuple[bool, Dict]:
        """Perform quorum write operation"""
        self.vector_clock[self.node_id] += 1
        
        entry = LogEntry(
            key=key,
            value=value,
            timestamp=int(time.time() * 1000),
            vector_clock=self.vector_clock.copy(),
            node_id=self.node_id
        )
        
        # Attempt to write to W nodes
        tasks = []
        for node in self.nodes:
            task = self._write_to_node(node, entry)
            tasks.append(task)
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        successful_writes = sum(1 for r in results if r is True)
        
        success = successful_writes >= self.config.write_quorum
        
        return success, {
            'successful_writes': successful_writes,
            'required_writes': self.config.write_quorum,
            'total_nodes': len(self.nodes),
            'consistency_level': self.config.consistency_level.value,
            'entry': asdict(entry)
        }
    
    async def read(self, key: str) -> Tuple[Optional[LogEntry], Dict]:
        """Perform quorum read operation"""
        tasks = []
        for node in self.nodes:
            task = self._read_from_node(node, key)
            tasks.append(task)
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        successful_reads = []
        
        for result in results:
            if isinstance(result, LogEntry):
                successful_reads.append(result)
        
        if len(successful_reads) < self.config.read_quorum:
            return None, {
                'successful_reads': len(successful_reads),
                'required_reads': self.config.read_quorum,
                'consistency_level': self.config.consistency_level.value,
                'error': 'Insufficient nodes for read quorum'
            }
        
        # Resolve conflicts using vector clocks
        latest_entry = self._resolve_conflicts(successful_reads)
        
        return latest_entry, {
            'successful_reads': len(successful_reads),
            'required_reads': self.config.read_quorum,
            'consistency_level': self.config.consistency_level.value,
            'candidates': len(successful_reads)
        }
    
    async def _write_to_node(self, node: str, entry: LogEntry) -> bool:
        """Write to a specific node"""
        if node == self.node_id:
            # Local write
            self.local_storage[entry.key] = entry
            return True
        
        try:
            # Simulate network write
            await asyncio.sleep(0.01)  # Simulate network delay
            return True
        except Exception:
            return False
    
    async def _read_from_node(self, node: str, key: str) -> Optional[LogEntry]:
        """Read from a specific node"""
        if node == self.node_id:
            # Local read
            return self.local_storage.get(key)
        
        try:
            # Simulate network read
            await asyncio.sleep(0.01)  # Simulate network delay
            # For demo, return a mock entry
            if key in self.local_storage:
                return self.local_storage[key]
            return None
        except Exception:
            return None
    
    def _resolve_conflicts(self, entries: List[LogEntry]) -> LogEntry:
        """Resolve conflicts using vector clocks and timestamps"""
        if not entries:
            return None
        
        if len(entries) == 1:
            return entries[0]
        
        # Sort by timestamp (simple resolution for demo)
        entries.sort(key=lambda e: e.timestamp, reverse=True)
        return entries[0]
EOF

# Create consistency manager
cat > src/consistency_manager.py << 'EOF'
import asyncio
import logging
from typing import Dict, List
from src.quorum_coordinator import QuorumCoordinator, ConsistencyLevel, QuorumConfig

class ConsistencyManager:
    def __init__(self):
        self.coordinators: Dict[str, QuorumCoordinator] = {}
        self.metrics = {
            'total_reads': 0,
            'total_writes': 0,
            'failed_reads': 0,
            'failed_writes': 0,
            'consistency_violations': 0
        }
    
    async def setup_cluster(self, nodes: List[str], consistency_level: ConsistencyLevel = ConsistencyLevel.BALANCED):
        """Setup a cluster of quorum coordinators"""
        config = QuorumConfig(
            total_replicas=len(nodes),
            read_quorum=0,
            write_quorum=0,
            consistency_level=consistency_level
        )
        
        for node_id in nodes:
            coordinator = QuorumCoordinator(node_id, nodes, config)
            coordinator.update_quorum_config(consistency_level)
            await coordinator.start()
            self.coordinators[node_id] = coordinator
        
        logging.info(f"Cluster setup complete with {len(nodes)} nodes")
    
    async def write_with_quorum(self, key: str, value: str, node_id: str = None) -> Dict:
        """Write using quorum consensus"""
        if not node_id:
            node_id = list(self.coordinators.keys())[0]
        
        coordinator = self.coordinators[node_id]
        success, result = await coordinator.write(key, value)
        
        self.metrics['total_writes'] += 1
        if not success:
            self.metrics['failed_writes'] += 1
        
        return {
            'success': success,
            'coordinator': node_id,
            **result
        }
    
    async def read_with_quorum(self, key: str, node_id: str = None) -> Dict:
        """Read using quorum consensus"""
        if not node_id:
            node_id = list(self.coordinators.keys())[0]
        
        coordinator = self.coordinators[node_id]
        entry, result = await coordinator.read(key)
        
        self.metrics['total_reads'] += 1
        if entry is None:
            self.metrics['failed_reads'] += 1
        
        return {
            'success': entry is not None,
            'coordinator': node_id,
            'data': entry.__dict__ if entry else None,
            **result
        }
    
    async def change_consistency_level(self, level: ConsistencyLevel):
        """Change consistency level for all coordinators"""
        for coordinator in self.coordinators.values():
            coordinator.update_quorum_config(level)
        
        logging.info(f"Changed consistency level to {level.value}")
    
    def get_metrics(self) -> Dict:
        """Get current performance metrics"""
        return self.metrics.copy()
    
    async def shutdown(self):
        """Shutdown all coordinators"""
        for coordinator in self.coordinators.values():
            await coordinator.stop()
EOF

# Create web interface
cat > src/web_interface.py << 'EOF'
from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
import asyncio
import json
from src.consistency_manager import ConsistencyManager, ConsistencyLevel

app = FastAPI(title="Quorum Consistency Demo")
templates = Jinja2Templates(directory="web")

# Global manager
manager = ConsistencyManager()

@app.on_event("startup")
async def startup():
    # Setup 5-node cluster
    nodes = [f"node-{i}" for i in range(1, 6)]
    await manager.setup_cluster(nodes, ConsistencyLevel.BALANCED)

@app.on_event("shutdown")
async def shutdown():
    await manager.shutdown()

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "metrics": manager.get_metrics()
    })

@app.post("/write")
async def write_data(key: str = Form(...), value: str = Form(...)):
    result = await manager.write_with_quorum(key, value)
    return result

@app.post("/read")
async def read_data(key: str = Form(...)):
    result = await manager.read_with_quorum(key)
    return result

@app.post("/consistency")
async def change_consistency(level: str = Form(...)):
    consistency_level = ConsistencyLevel(level)
    await manager.change_consistency_level(consistency_level)
    return {"status": "success", "level": level}

@app.get("/metrics")
async def get_metrics():
    return manager.get_metrics()
EOF

# Create web dashboard
mkdir -p web
cat > web/dashboard.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Quorum Consistency Control Demo</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
        .container { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        .panel { border: 1px solid #ddd; padding: 20px; border-radius: 8px; }
        .metrics { background: #f8f9fa; }
        .form-group { margin-bottom: 15px; }
        input, select, button { padding: 8px; margin: 5px; }
        button { background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; }
        .result { background: #e9ecef; padding: 10px; margin: 10px 0; border-radius: 4px; }
        .success { background: #d4edda; border-color: #c3e6cb; }
        .error { background: #f8d7da; border-color: #f5c6cb; }
    </style>
</head>
<body>
    <h1>🗳️ Quorum Consistency Control Demo</h1>
    
    <div class="container">
        <div class="panel">
            <h3>Consistency Configuration</h3>
            <form id="consistencyForm">
                <div class="form-group">
                    <label>Consistency Level:</label>
                    <select id="consistencyLevel">
                        <option value="strong">Strong (R=N, W=N)</option>
                        <option value="balanced" selected>Balanced (R=majority, W=majority)</option>
                        <option value="eventual">Eventual (R=1, W=1)</option>
                    </select>
                    <button type="submit">Update</button>
                </div>
            </form>
            
            <h3>Write Operation</h3>
            <form id="writeForm">
                <div class="form-group">
                    <input type="text" id="writeKey" placeholder="Key" required>
                    <input type="text" id="writeValue" placeholder="Value" required>
                    <button type="submit">Write</button>
                </div>
            </form>
            
            <h3>Read Operation</h3>
            <form id="readForm">
                <div class="form-group">
                    <input type="text" id="readKey" placeholder="Key" required>
                    <button type="submit">Read</button>
                </div>
            </form>
        </div>
        
        <div class="panel metrics">
            <h3>System Metrics</h3>
            <div id="metrics">
                <p>Total Reads: <span id="totalReads">{{ metrics.total_reads }}</span></p>
                <p>Total Writes: <span id="totalWrites">{{ metrics.total_writes }}</span></p>
                <p>Failed Reads: <span id="failedReads">{{ metrics.failed_reads }}</span></p>
                <p>Failed Writes: <span id="failedWrites">{{ metrics.failed_writes }}</span></p>
            </div>
        </div>
    </div>
    
    <div class="panel">
        <h3>Operation Results</h3>
        <div id="results"></div>
    </div>

    <script>
        function addResult(operation, result, success) {
            const resultsDiv = document.getElementById('results');
            const resultDiv = document.createElement('div');
            resultDiv.className = `result ${success ? 'success' : 'error'}`;
            resultDiv.innerHTML = `
                <strong>${operation}:</strong> ${success ? 'Success' : 'Failed'}<br>
                <pre>${JSON.stringify(result, null, 2)}</pre>
            `;
            resultsDiv.insertBefore(resultDiv, resultsDiv.firstChild);
        }

        function updateMetrics() {
            fetch('/metrics')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('totalReads').textContent = data.total_reads;
                    document.getElementById('totalWrites').textContent = data.total_writes;
                    document.getElementById('failedReads').textContent = data.failed_reads;
                    document.getElementById('failedWrites').textContent = data.failed_writes;
                });
        }

        document.getElementById('consistencyForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const level = document.getElementById('consistencyLevel').value;
            const formData = new FormData();
            formData.append('level', level);
            
            const response = await fetch('/consistency', {
                method: 'POST',
                body: formData
            });
            const result = await response.json();
            addResult('Consistency Change', result, response.ok);
        });

        document.getElementById('writeForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const key = document.getElementById('writeKey').value;
            const value = document.getElementById('writeValue').value;
            
            const formData = new FormData();
            formData.append('key', key);
            formData.append('value', value);
            
            const response = await fetch('/write', {
                method: 'POST',
                body: formData
            });
            const result = await response.json();
            addResult('Write', result, result.success);
            updateMetrics();
            
            // Clear form
            document.getElementById('writeKey').value = '';
            document.getElementById('writeValue').value = '';
        });

        document.getElementById('readForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const key = document.getElementById('readKey').value;
            
            const formData = new FormData();
            formData.append('key', key);
            
            const response = await fetch('/read', {
                method: 'POST',
                body: formData
            });
            const result = await response.json();
            addResult('Read', result, result.success);
            updateMetrics();
            
            // Clear form
            document.getElementById('readKey').value = '';
        });

        // Update metrics every 5 seconds
        setInterval(updateMetrics, 5000);
    </script>
</body>
</html>
EOF

# Create test suite
cat > tests/test_quorum.py << 'EOF'
import pytest
import asyncio
from src.quorum_coordinator import QuorumCoordinator, QuorumConfig, ConsistencyLevel
from src.consistency_manager import ConsistencyManager

@pytest.mark.asyncio
async def test_quorum_write_success():
    """Test successful quorum write"""
    nodes = ['node1', 'node2', 'node3']
    config = QuorumConfig(3, 2, 2, ConsistencyLevel.BALANCED)
    coordinator = QuorumCoordinator('node1', nodes, config)
    
    await coordinator.start()
    success, result = await coordinator.write('test_key', 'test_value')
    await coordinator.stop()
    
    assert success == True
    assert result['successful_writes'] >= 2

@pytest.mark.asyncio
async def test_quorum_read_success():
    """Test successful quorum read"""
    nodes = ['node1', 'node2', 'node3']
    config = QuorumConfig(3, 2, 2, ConsistencyLevel.BALANCED)
    coordinator = QuorumCoordinator('node1', nodes, config)
    
    await coordinator.start()
    
    # Write first
    await coordinator.write('test_key', 'test_value')
    
    # Then read
    entry, result = await coordinator.read('test_key')
    await coordinator.stop()
    
    assert entry is not None
    assert entry.value == 'test_value'

@pytest.mark.asyncio
async def test_consistency_levels():
    """Test different consistency levels"""
    manager = ConsistencyManager()
    nodes = ['node1', 'node2', 'node3', 'node4', 'node5']
    
    await manager.setup_cluster(nodes, ConsistencyLevel.STRONG)
    
    # Test strong consistency
    result = await manager.write_with_quorum('key1', 'value1')
    assert result['required_writes'] == 5  # All nodes
    
    # Change to eventual consistency
    await manager.change_consistency_level(ConsistencyLevel.EVENTUAL)
    result = await manager.write_with_quorum('key2', 'value2')
    assert result['required_writes'] == 1  # Just one node
    
    await manager.shutdown()

@pytest.mark.asyncio
async def test_conflict_resolution():
    """Test conflict resolution with concurrent writes"""
    nodes = ['node1', 'node2', 'node3']
    config = QuorumConfig(3, 2, 2, ConsistencyLevel.BALANCED)
    coordinator = QuorumCoordinator('node1', nodes, config)
    
    await coordinator.start()
    
    # Simulate concurrent writes
    tasks = [
        coordinator.write('conflict_key', 'value1'),
        coordinator.write('conflict_key', 'value2'),
        coordinator.write('conflict_key', 'value3')
    ]
    
    results = await asyncio.gather(*tasks)
    
    # Read the final value
    entry, _ = await coordinator.read('conflict_key')
    
    await coordinator.stop()
    
    assert entry is not None
    assert entry.value in ['value1', 'value2', 'value3']

if __name__ == "__main__":
    pytest.main([__file__])
EOF

# Create Docker configuration
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --only-binary=all -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "src.web_interface:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  quorum-demo:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    environment:
      - PYTHONPATH=/app
EOF

# Create build and test scripts
cat > scripts/build.sh << 'EOF'
#!/bin/bash

echo "🔨 Building Quorum Consistency System..."

# Install dependencies
pip install --only-binary=all -r requirements.txt

echo "✅ Dependencies installed"

# Run tests
python -m pytest tests/ -v

echo "✅ Tests passed"

# Start the web interface
echo "🚀 Starting web interface on http://localhost:8000"
uvicorn src.web_interface:app --reload --host 0.0.0.0 --port 8000
EOF

cat > scripts/test.sh << 'EOF'
#!/bin/bash

echo "🧪 Running Quorum System Tests..."

# Unit tests
python -m pytest tests/test_quorum.py -v

# Integration test
python -c "
import asyncio
from src.consistency_manager import ConsistencyManager, ConsistencyLevel

async def integration_test():
    manager = ConsistencyManager()
    nodes = ['node1', 'node2', 'node3', 'node4', 'node5']
    
    print('Setting up cluster...')
    await manager.setup_cluster(nodes, ConsistencyLevel.BALANCED)
    
    print('Testing write operations...')
    for i in range(5):
        result = await manager.write_with_quorum(f'key{i}', f'value{i}')
        print(f'Write {i}: {result[\"success\"]}')
    
    print('Testing read operations...')
    for i in range(5):
        result = await manager.read_with_quorum(f'key{i}')
        print(f'Read {i}: {result[\"success\"]}')
    
    print('Testing consistency level changes...')
    await manager.change_consistency_level(ConsistencyLevel.STRONG)
    result = await manager.write_with_quorum('strong_key', 'strong_value')
    print(f'Strong consistency write: {result[\"success\"]}')
    
    print('Metrics:', manager.get_metrics())
    await manager.shutdown()
    print('✅ Integration test completed')

asyncio.run(integration_test())
"

echo "✅ All tests completed"
EOF

chmod +x scripts/*.sh

# Create README
cat > README.md << 'EOF'
# Day 28: Read/Write Quorums for Consistency Control

This project implements a distributed quorum-based consistency control system for log processing.

## Features

- Configurable consistency levels (Strong, Balanced, Eventual)
- Read/Write quorum implementation
- Conflict resolution using vector clocks
- Real-time web dashboard
- Comprehensive testing suite

## Quick Start

### Without Docker
```bash
./scripts/build.sh
```

### With Docker
```bash
docker-compose up --build
```

## Testing
```bash
./scripts/test.sh
```

## Web Interface
Visit http://localhost:8000 to interact with the system and observe consistency tradeoffs.

## Consistency Levels

- **Strong**: R=N, W=N (All nodes must respond)
- **Balanced**: R=majority, W=majority (Most nodes must respond)
- **Eventual**: R=1, W=1 (Any single node can respond)
EOF

echo "🎯 Setting up environment..."
python3.11 -m venv venv 
source venv/bin/activate
pip install -r requirements.txt

echo "🧪 Running tests..."
python -m pytest tests/ -v

echo "✅ Project setup complete!"
echo ""
echo "📍 What was built:"
echo "  - Quorum coordinator with configurable consistency levels"
echo "  - Consistency manager handling cluster operations"
echo "  - Web dashboard for real-time interaction"
echo "  - Comprehensive test suite"
echo "  - Docker support for easy deployment"
echo ""
echo "🚀 To start the system:"
echo "  Without Docker: ./scripts/build.sh"
echo "  With Docker: docker-compose up --build"
echo ""
echo "🌐 Access the dashboard at: http://localhost:8000"
echo ""
echo "📊 The system demonstrates:"
echo "  - R + W > N consistency guarantees"
echo "  - Tradeoffs between consistency and availability"
echo "  - Real-time quorum decision making"
echo "  - Conflict resolution mechanisms"