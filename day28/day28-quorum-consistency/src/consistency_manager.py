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
