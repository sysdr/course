import asyncio
import httpx
import threading
import time
from concurrent.futures import ThreadPoolExecutor
import json

class ReplicationManager:
    def __init__(self, source_node, target_nodes, replication_factor=2):
        self.source_node = source_node
        self.target_nodes = target_nodes
        self.replication_factor = min(replication_factor, len(target_nodes))
        self.executor = ThreadPoolExecutor(max_workers=5)
        self.stats = {
            'replications_attempted': 0,
            'replications_successful': 0,
            'replications_failed': 0
        }
        
    async def replicate_file_async(self, file_path, file_data):
        """Replicate file to target nodes asynchronously"""
        if not self.target_nodes:
            return True
            
        self.stats['replications_attempted'] += 1
        
        # Select target nodes (round-robin or health-based)
        selected_targets = self._select_healthy_targets()
        
        if not selected_targets:
            print("No healthy targets available for replication")
            self.stats['replications_failed'] += 1
            return False
        
        tasks = []
        for target_node in selected_targets[:self.replication_factor]:
            task = self._replicate_to_node(target_node, file_path, file_data)
            tasks.append(task)
        
        # Execute replication tasks concurrently
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Count successful replications
        successful_count = sum(1 for result in results if result is True)
        
        if successful_count > 0:
            self.stats['replications_successful'] += 1
            print(f"Replication successful: {successful_count}/{len(selected_targets)} nodes")
            return True
        else:
            self.stats['replications_failed'] += 1
            print("Replication failed to all target nodes")
            return False
    
    def replicate_file_sync(self, file_path, file_data):
        """Synchronous wrapper for async replication"""
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            return loop.run_until_complete(self.replicate_file_async(file_path, file_data))
        finally:
            loop.close()
    
    async def _replicate_to_node(self, target_node, file_path, file_data):
        """Replicate file to a specific target node"""
        try:
            url = f"http://{target_node['host']}:{target_node['port']}/replicate"
            payload = {
                'file_path': file_path,
                'data': file_data
            }
            
            timeout = httpx.Timeout(10.0)
            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(url, json=payload)
                if response.status_code == 200:
                    result = response.json()
                    return result.get('success', False)
                else:
                    print(f"Replication failed to {target_node['id']}: HTTP {response.status_code}")
                    return False
        except asyncio.TimeoutError:
            print(f"Replication timeout to {target_node['id']}")
            return False
        except Exception as e:
            print(f"Replication error to {target_node['id']}: {e}")
            return False
    
    def _select_healthy_targets(self):
        """Select healthy target nodes for replication"""
        # For now, return all targets. In production, implement health checking
        return self.target_nodes
    
    def get_stats(self):
        """Get replication statistics"""
        return self.stats.copy()
