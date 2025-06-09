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
