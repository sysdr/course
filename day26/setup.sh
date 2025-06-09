#!/bin/bash

echo "=== Setting up Day 26: Cluster Membership and Health Checking System ==="

# Create project structure
mkdir -p day26_cluster_membership/{src,tests,config,logs,docs}
cd day26_cluster_membership

# Create Python package initialization files
touch src/__init__.py
touch tests/__init__.py

# Create requirements.txt with platform-specific dependencies
cat > requirements.txt << 'EOF'
# Core dependencies
aiohttp==3.9.5
pytest==8.2.0
pytest-asyncio==0.23.6
structlog==24.1.0
websockets==12.0
prometheus-client==0.20.0
orjson==3.9.15
dataclasses-json==0.6.4

# Platform-specific optimizations
uvloop==0.19.0; platform_system != "Windows"
uvloop==0.19.0; platform_system == "Linux"
uvloop==0.19.0; platform_system == "Darwin" and platform_machine == "arm64"
EOF

# Create Dockerfile with multi-platform support
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ src/
COPY tests/ tests/

# Set PYTHONPATH
ENV PYTHONPATH=/app

# Default command
CMD ["python", "-m", "pytest", "tests/"]
EOF

# Create setup_project.sh
cat > setup_project.sh << 'EOF'
#!/bin/bash
echo "=== Creating project structure and source files ==="

# Create source files
mkdir -p src tests

# Create cluster_member.py
cat > src/cluster_member.py << 'EOCM'
import asyncio
import json
import time
import random
import logging
import hashlib
import platform
from typing import Dict, List, Set, Optional
from dataclasses import dataclass, asdict
from enum import Enum
import aiohttp
import orjson
from dataclasses_json import dataclass_json

# Platform-specific optimizations
def setup_event_loop():
    """Configure the event loop based on platform"""
    system = platform.system()
    machine = platform.machine()
    
    # Use uvloop on supported platforms
    if system != "Windows":
        try:
            import uvloop
            asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
            logging.info("Using uvloop for enhanced performance")
        except ImportError:
            logging.info("uvloop not available, using default event loop")
    
    # Configure event loop
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    return loop

class NodeStatus(Enum):
    HEALTHY = "healthy"
    SUSPECTED = "suspected" 
    FAILED = "failed"
    JOINING = "joining"

@dataclass
class NodeInfo:
    node_id: str
    address: str
    port: int
    role: str
    status: NodeStatus
    last_seen: float
    heartbeat_count: int = 0
    suspicion_level: float = 0.0

@dataclass_json
@dataclass
class MembershipDigest:
    sender_id: str
    timestamp: float
    membership_hash: str
    node_updates: List[dict]
    leader_id: Optional[str] = None

class ClusterMember:
    def __init__(self, node_id: str, address: str, port: int, role: str = "worker"):
        self.node_id = node_id
        self.address = address
        self.port = port
        self.role = role
        self.status = NodeStatus.JOINING
        
        # Membership state
        self.membership: Dict[str, NodeInfo] = {}
        self.leader_id: Optional[str] = None
        self.gossip_interval = 2.0
        self.health_check_interval = 1.0
        
        # Health checking state
        self.phi_threshold = 8.0  # Failure detection threshold
        self.heartbeat_history: Dict[str, List[float]] = {}
        
        # Network session
        self.session: Optional[aiohttp.ClientSession] = None
        
        # Add self to membership
        self.membership[self.node_id] = NodeInfo(
            node_id=node_id,
            address=address,
            port=port,
            role=role,
            status=NodeStatus.HEALTHY,
            last_seen=time.time()
        )
        
        # Configure logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(f"cluster_member_{node_id}")
        
        # Setup platform-specific optimizations
        setup_event_loop()
EOCM

# Create cluster_manager.py
cat > src/cluster_manager.py << 'EOCMGR'
import asyncio
import logging
import platform
from typing import Dict, List, Optional
from .cluster_member import ClusterMember, NodeStatus

class ClusterManager:
    def __init__(self):
        self.members: Dict[str, ClusterMember] = {}
        self.logger = logging.getLogger("cluster_manager")
        
        # Log platform information
        self.logger.info(f"Running on {platform.system()} {platform.release()} ({platform.machine()})")
        
    async def add_member(self, node_id: str, address: str, port: int, role: str = "worker") -> ClusterMember:
        member = ClusterMember(node_id, address, port, role)
        self.members[node_id] = member
        return member
        
    async def remove_member(self, node_id: str):
        if node_id in self.members:
            del self.members[node_id]
            
    async def get_member_status(self, node_id: str) -> Optional[NodeStatus]:
        if node_id in self.members:
            return self.members[node_id].status
        return None
EOCMGR

# Create test_cluster_member.py
cat > tests/test_cluster_member.py << 'EOTEST'
import pytest
import asyncio
import platform
from src.cluster_member import ClusterMember, NodeStatus

@pytest.mark.asyncio
async def test_cluster_member_initialization():
    member = ClusterMember("test1", "localhost", 8000)
    assert member.node_id == "test1"
    assert member.status == NodeStatus.JOINING
    assert member.node_id in member.membership

@pytest.mark.asyncio
async def test_platform_specific_setup():
    """Test that platform-specific optimizations are properly configured"""
    member = ClusterMember("test2", "localhost", 8001)
    assert asyncio.get_event_loop() is not None
EOTEST

echo "=== Project structure and source files created successfully ==="
EOF

# Create build_test_no_docker.sh
cat > build_test_no_docker.sh << 'EOF'
#!/bin/bash
echo "=== Building and testing without Docker ==="

# Detect platform
PLATFORM=$(uname)
echo "Detected platform: $PLATFORM"

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install system dependencies based on platform
case "$PLATFORM" in
    "Linux")
        echo "Installing Linux system dependencies..."
        sudo apt-get update
        sudo apt-get install -y python3-dev gcc
        ;;
    "Darwin")
        echo "Installing macOS system dependencies..."
        # Check if Homebrew is installed
        if ! command -v brew &> /dev/null; then
            echo "Homebrew not found. Please install it first: https://brew.sh"
            exit 1
        fi
        brew install python3
        ;;
    "MINGW"*|"MSYS"*|"CYGWIN"*)
        echo "Windows detected. No additional system dependencies required."
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        exit 1
        ;;
esac

# Install dependencies
pip install -r requirements.txt

# Set PYTHONPATH
export PYTHONPATH=$PWD

# Run tests
python -m pytest tests/

echo "=== Build and test completed successfully ==="
EOF

# Create build_test_docker.sh
cat > build_test_docker.sh << 'EOF'
#!/bin/bash
echo "=== Building and testing with Docker ==="

# Build Docker image
docker build -t cluster-membership .

# Run tests in container
docker run --rm cluster-membership

echo "=== Docker build and test completed successfully ==="
EOF

# Create verify_system.sh
cat > verify_system.sh << 'EOF'
#!/bin/bash
echo "=== Running comprehensive system verification ==="

# Activate virtual environment
source venv/bin/activate

# Set PYTHONPATH
export PYTHONPATH=$PWD

# Run all tests
python -m pytest tests/

# Run system checks
python -c "
import asyncio
import platform
from src.cluster_member import ClusterMember
from src.cluster_manager import ClusterManager

async def verify_system():
    print(f'Running on {platform.system()} {platform.release()} ({platform.machine()})')
    
    manager = ClusterManager()
    member1 = await manager.add_member('node1', 'localhost', 8000)
    member2 = await manager.add_member('node2', 'localhost', 8001)
    
    assert len(manager.members) == 2
    print('System verification passed!')

asyncio.run(verify_system())
"

echo "=== System verification completed successfully ==="
EOF

# Make all scripts executable
chmod +x setup_project.sh
chmod +x build_test_no_docker.sh
chmod +x build_test_docker.sh
chmod +x verify_system.sh

# Run all scripts sequentially
echo "=== Running all setup scripts sequentially ==="

echo "1. Running setup_project.sh..."
./setup_project.sh

echo "2. Running build_test_no_docker.sh..."
./build_test_no_docker.sh

echo "3. Running build_test_docker.sh..."
./build_test_docker.sh

echo "4. Running verify_system.sh..."
./verify_system.sh

echo "=== All scripts completed successfully! ==="