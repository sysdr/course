import asyncio
import logging
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from datetime import datetime

@dataclass
class ReadRepairResult:
    """Result of read repair operation"""
    success: bool
    inconsistencies_found: int
    repairs_performed: int
    error_message: Optional[str] = None

class ReadRepairEngine:
    """Handles read repair during normal read operations"""
    
    def __init__(self, nodes: Dict[str, 'StorageNode']):
        self.nodes = nodes
        self.logger = logging.getLogger(__name__)
        self.repair_threshold = 0.5  # Repair if > 50% of replicas disagree
        
    async def read_with_repair(self, key: str, read_quorum: int = 2) -> Optional[Any]:
        """Perform read with automatic read repair"""
        try:
            # Read from multiple replicas
            responses = await self._read_from_replicas(key, read_quorum + 1)
            
            if not responses:
                return None
            
            # Check for consistency
            consistency_check = self._check_consistency(responses)
            
            if not consistency_check['consistent']:
                # Perform read repair
                repair_result = await self._perform_read_repair(key, responses)
                self.logger.info(f"Read repair performed for key {key}: {repair_result}")
            
            # Return the most recent/authoritative value
            return self._select_authoritative_value(responses)
            
        except Exception as e:
            self.logger.error(f"Error in read with repair for key {key}: {e}")
            return None
    
    async def _read_from_replicas(self, key: str, replica_count: int) -> List[Dict]:
        """Read from multiple replicas"""
        responses = []
        node_names = list(self.nodes.keys())[:replica_count]
        
        tasks = []
        for node_name in node_names:
            task = asyncio.create_task(self._read_from_node(node_name, key))
            tasks.append((node_name, task))
        
        for node_name, task in tasks:
            try:
                result = await task
                if result is not None:
                    responses.append({
                        'node': node_name,
                        'data': result,
                        'timestamp': getattr(result, 'timestamp', datetime.now())
                    })
            except Exception as e:
                self.logger.warning(f"Failed to read from {node_name}: {e}")
        
        return responses
    
    async def _read_from_node(self, node_name: str, key: str) -> Optional[Any]:
        """Read from a specific node"""
        node = self.nodes[node_name]
        return await node.get_entry(key)
    
    def _check_consistency(self, responses: List[Dict]) -> Dict:
        """Check consistency across responses"""
        if len(responses) <= 1:
            return {'consistent': True, 'conflicts': []}
        
        # Group responses by data content
        value_groups = {}
        for response in responses:
            data_hash = str(hash(str(response['data'])))
            if data_hash not in value_groups:
                value_groups[data_hash] = []
            value_groups[data_hash].append(response)
        
        consistent = len(value_groups) == 1
        conflicts = []
        
        if not consistent:
            for group in value_groups.values():
                conflicts.extend(group)
        
        return {
            'consistent': consistent,
            'conflicts': conflicts,
            'value_groups': value_groups
        }
    
    async def _perform_read_repair(self, key: str, responses: List[Dict]) -> ReadRepairResult:
        """Perform read repair to fix inconsistencies"""
        try:
            # Determine the authoritative value (most recent timestamp)
            authoritative_response = max(responses, key=lambda r: r['timestamp'])
            authoritative_value = authoritative_response['data']
            
            repairs_performed = 0
            inconsistencies_found = 0
            
            # Update nodes with stale data
            for response in responses:
                if response['data'] != authoritative_value:
                    inconsistencies_found += 1
                    node_name = response['node']
                    
                    try:
                        node = self.nodes[node_name]
                        await node.repair_entry(authoritative_value)
                        repairs_performed += 1
                        self.logger.info(f"Repaired {key} on {node_name}")
                    except Exception as e:
                        self.logger.error(f"Failed to repair {key} on {node_name}: {e}")
            
            return ReadRepairResult(
                success=True,
                inconsistencies_found=inconsistencies_found,
                repairs_performed=repairs_performed
            )
            
        except Exception as e:
            return ReadRepairResult(
                success=False,
                inconsistencies_found=0,
                repairs_performed=0,
                error_message=str(e)
            )
    
    def _select_authoritative_value(self, responses: List[Dict]) -> Any:
        """Select the most authoritative value from responses"""
        if not responses:
            return None
        
        # Return value with latest timestamp
        latest_response = max(responses, key=lambda r: r['timestamp'])
        return latest_response['data']
    
    async def check_and_repair_range(self, start_key: str, end_key: str) -> Dict:
        """Check and repair a range of keys"""
        repair_stats = {
            'keys_checked': 0,
            'inconsistencies_found': 0,
            'repairs_performed': 0,
            'errors': []
        }
        
        try:
            # Get all keys in range from first node
            first_node = list(self.nodes.values())[0]
            keys_in_range = await first_node.get_keys_in_range(start_key, end_key)
            
            for key in keys_in_range:
                repair_stats['keys_checked'] += 1
                
                try:
                    responses = await self._read_from_replicas(key, len(self.nodes))
                    consistency_check = self._check_consistency(responses)
                    
                    if not consistency_check['consistent']:
                        repair_result = await self._perform_read_repair(key, responses)
                        repair_stats['inconsistencies_found'] += repair_result.inconsistencies_found
                        repair_stats['repairs_performed'] += repair_result.repairs_performed
                        
                except Exception as e:
                    repair_stats['errors'].append(f"Error repairing {key}: {e}")
            
        except Exception as e:
            repair_stats['errors'].append(f"Error in range repair: {e}")
        
        return repair_stats
