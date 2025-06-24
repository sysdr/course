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
