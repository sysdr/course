import asyncio
import time
from typing import Dict, List
from src.raft_node import RaftNode, NodeState

class ClusterManager:
    def __init__(self, cluster_config: Dict):
        self.nodes = {}
        self.cluster_config = cluster_config
        
    async def start_cluster(self):
        """Start all nodes in the cluster"""
        print("🚀 Starting distributed log cluster...")
        
        # Create nodes
        for node_config in self.cluster_config['nodes']:
            node_id = node_config['id']
            peers = [n['id'] for n in self.cluster_config['nodes'] if n['id'] != node_id]
            
            node = RaftNode(
                node_id=node_id,
                peers=peers,
                port=node_config['port']
            )
            
            self.nodes[node_id] = node
            
        # Start all nodes
        start_tasks = []
        for node in self.nodes.values():
            task = asyncio.create_task(node.start())
            start_tasks.append(task)
        
        await asyncio.gather(*start_tasks, return_exceptions=True)
        
    async def stop_cluster(self):
        """Stop all nodes"""
        stop_tasks = []
        for node in self.nodes.values():
            task = asyncio.create_task(node.stop())
            stop_tasks.append(task)
        
        await asyncio.gather(*stop_tasks, return_exceptions=True)
        
    def get_cluster_status(self) -> Dict:
        """Get status of all nodes"""
        return {
            "cluster_size": len(self.nodes),
            "nodes": {node_id: node.get_status() for node_id, node in self.nodes.items()},
            "leader": self._find_leader(),
            "timestamp": time.time()
        }
    
    def _find_leader(self) -> str:
        """Find current leader"""
        for node_id, node in self.nodes.items():
            if node.state == NodeState.LEADER:
                return node_id
        return None

    async def simulate_failure(self, node_id: str):
        """Simulate node failure"""
        if node_id in self.nodes:
            print(f"💥 Simulating failure of node {node_id}")
            await self.nodes[node_id].stop()
            
    async def recover_node(self, node_id: str):
        """Recover failed node"""
        if node_id in self.nodes:
            print(f"🔄 Recovering node {node_id}")
            await self.nodes[node_id].start()
