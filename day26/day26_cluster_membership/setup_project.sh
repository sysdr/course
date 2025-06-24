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
