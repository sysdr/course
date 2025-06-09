import asyncio
import json
import time
from typing import Dict, List, Set, Optional
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
import logging

from .merkle_tree import MerkleTree

@dataclass
class RepairTask:
    """Represents a repair task"""
    source_node: str
    target_node: str
    missing_data: List[str]
    priority: int
    created_at: datetime
    status: str = "pending"  # pending, in_progress, completed, failed

@dataclass
class ConsistencyMetrics:
    """Tracks consistency metrics"""
    total_comparisons: int = 0
    inconsistencies_detected: int = 0
    repairs_completed: int = 0
    repairs_failed: int = 0
    last_scan_time: Optional[datetime] = None
    average_repair_time: float = 0.0

class AntiEntropyCoordinator:
    """Coordinates anti-entropy operations across the cluster"""
    
    def __init__(self, nodes: Dict[str, 'StorageNode'], scan_interval: int = 30):
        self.nodes = nodes
        self.scan_interval = scan_interval
        self.repair_queue: List[RepairTask] = []
        self.metrics = ConsistencyMetrics()
        self.running = False
        self.logger = logging.getLogger(__name__)
        
    async def start(self):
        """Start the anti-entropy coordinator"""
        self.running = True
        self.logger.info("Anti-entropy coordinator started")
        
        # Start background tasks
        tasks = [
            asyncio.create_task(self._scheduled_scan_loop()),
            asyncio.create_task(self._repair_worker_loop())
        ]
        
        await asyncio.gather(*tasks)
    
    async def stop(self):
        """Stop the anti-entropy coordinator"""
        self.running = False
        self.logger.info("Anti-entropy coordinator stopped")
    
    async def _scheduled_scan_loop(self):
        """Main loop for scheduled Merkle tree comparisons"""
        while self.running:
            try:
                await self._perform_cluster_scan()
                await asyncio.sleep(self.scan_interval)
            except Exception as e:
                self.logger.error(f"Error in scheduled scan: {e}")
                await asyncio.sleep(5)
    
    async def _repair_worker_loop(self):
        """Worker loop for processing repair tasks"""
        while self.running:
            try:
                if self.repair_queue:
                    task = self.repair_queue.pop(0)
                    await self._execute_repair_task(task)
                else:
                    await asyncio.sleep(1)
            except Exception as e:
                self.logger.error(f"Error in repair worker: {e}")
                await asyncio.sleep(1)
    
    async def _perform_cluster_scan(self):
        """Perform full cluster consistency scan"""
        self.logger.info("Starting cluster consistency scan")
        start_time = time.time()
        
        node_names = list(self.nodes.keys())
        comparisons = 0
        
        # Compare each pair of nodes
        for i in range(len(node_names)):
            for j in range(i + 1, len(node_names)):
                node_a_name = node_names[i]
                node_b_name = node_names[j]
                
                await self._compare_nodes(node_a_name, node_b_name)
                comparisons += 1
        
        self.metrics.total_comparisons += comparisons
        self.metrics.last_scan_time = datetime.now()
        
        scan_duration = time.time() - start_time
        self.logger.info(f"Cluster scan completed in {scan_duration:.2f}s, {comparisons} comparisons")
    
    async def _compare_nodes(self, node_a_name: str, node_b_name: str):
        """Compare Merkle trees between two nodes"""
        try:
            node_a = self.nodes[node_a_name]
            node_b = self.nodes[node_b_name]
            
            # Get Merkle trees from both nodes
            tree_a = await node_a.get_merkle_tree()
            tree_b = await node_b.get_merkle_tree()
            
            # Compare root hashes first
            if tree_a.get_root_hash() != tree_b.get_root_hash():
                self.logger.warning(f"Inconsistency detected between {node_a_name} and {node_b_name}")
                self.metrics.inconsistencies_detected += 1
                
                # Find specific differences
                differences = tree_a.compare_with(tree_b)
                await self._schedule_repair(node_a_name, node_b_name, differences)
                
        except Exception as e:
            self.logger.error(f"Error comparing {node_a_name} and {node_b_name}: {e}")
    
    async def _schedule_repair(self, node_a_name: str, node_b_name: str, differences: List[str]):
        """Schedule repair tasks for detected inconsistencies"""
        # Determine which node has more recent data
        node_a = self.nodes[node_a_name]
        node_b = self.nodes[node_b_name]
        
        # Simple heuristic: node with more entries is likely more up-to-date
        a_count = await node_a.get_entry_count()
        b_count = await node_b.get_entry_count()
        
        if a_count > b_count:
            source_node, target_node = node_a_name, node_b_name
        else:
            source_node, target_node = node_b_name, node_a_name
        
        # Create repair task
        task = RepairTask(
            source_node=source_node,
            target_node=target_node,
            missing_data=differences,
            priority=len(differences),  # Higher priority for more differences
            created_at=datetime.now()
        )
        
        self.repair_queue.append(task)
        self.repair_queue.sort(key=lambda x: x.priority, reverse=True)
        
        self.logger.info(f"Scheduled repair: {source_node} -> {target_node}, {len(differences)} differences")
    
    async def _execute_repair_task(self, task: RepairTask):
        """Execute a repair task"""
        start_time = time.time()
        task.status = "in_progress"
        
        try:
            source_node = self.nodes[task.source_node]
            target_node = self.nodes[task.target_node]
            
            # Get missing data from source node
            missing_entries = await source_node.get_missing_entries(task.missing_data)
            
            # Send data to target node
            for entry in missing_entries:
                await target_node.repair_entry(entry)
            
            task.status = "completed"
            self.metrics.repairs_completed += 1
            
            repair_time = time.time() - start_time
            self._update_average_repair_time(repair_time)
            
            self.logger.info(f"Repair completed: {task.source_node} -> {task.target_node} in {repair_time:.2f}s")
            
        except Exception as e:
            task.status = "failed"
            self.metrics.repairs_failed += 1
            self.logger.error(f"Repair failed: {task.source_node} -> {task.target_node}: {e}")
    
    def _update_average_repair_time(self, repair_time: float):
        """Update average repair time metric"""
        total_repairs = self.metrics.repairs_completed + self.metrics.repairs_failed
        if total_repairs == 1:
            self.metrics.average_repair_time = repair_time
        else:
            self.metrics.average_repair_time = (
                (self.metrics.average_repair_time * (total_repairs - 1) + repair_time) / total_repairs
            )
    
    async def trigger_immediate_scan(self):
        """Trigger immediate cluster scan"""
        self.logger.info("Triggering immediate cluster scan")
        await self._perform_cluster_scan()
    
    def get_metrics(self) -> Dict:
        """Get current consistency metrics"""
        return asdict(self.metrics)
    
    def get_repair_queue_status(self) -> List[Dict]:
        """Get current repair queue status"""
        return [asdict(task) for task in self.repair_queue]
