import unittest
import asyncio
import tempfile
import shutil
from src.storage.node import StorageNode
from src.anti_entropy.coordinator import AntiEntropyCoordinator
from src.anti_entropy.read_repair import ReadRepairEngine

class TestAntiEntropy(unittest.TestCase):
    
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.nodes = {}
        
        # Create test nodes
        for node_id in ['node_a', 'node_b', 'node_c']:
            node_dir = f"{self.temp_dir}/{node_id}"
            self.nodes[node_id] = StorageNode(node_id, node_dir)
    
    def tearDown(self):
        shutil.rmtree(self.temp_dir)
    
    def test_consistency_detection(self):
        async def run_test():
            # Add different data to nodes
            await self.nodes['node_a'].put_entry('key1', 'value1')
            await self.nodes['node_b'].put_entry('key1', 'value2')  # Inconsistency
            await self.nodes['node_c'].put_entry('key1', 'value1')
            
            # Create coordinator
            coordinator = AntiEntropyCoordinator(self.nodes, scan_interval=1)
            
            # Perform scan
            await coordinator._perform_cluster_scan()
            
            # Check that inconsistency was detected
            metrics = coordinator.get_metrics()
            self.assertGreater(metrics['inconsistencies_detected'], 0)
        
        asyncio.run(run_test())
    
    def test_read_repair(self):
        async def run_test():
            # Setup inconsistent data
            await self.nodes['node_a'].put_entry('key1', 'correct_value')
            await self.nodes['node_b'].put_entry('key1', 'wrong_value')
            
            # Create read repair engine
            read_repair = ReadRepairEngine(self.nodes)
            
            # Perform read with repair
            result = await read_repair.read_with_repair('key1', read_quorum=2)
            
            # Should return the most recent value
            self.assertIsNotNone(result)
        
        asyncio.run(run_test())

if __name__ == '__main__':
    unittest.main()
