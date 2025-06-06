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
