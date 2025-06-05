import hashlib
import bisect
import json
from typing import Dict, List, Optional, Tuple
from collections import defaultdict

class ConsistentHashRing:
    """
    Implements consistent hashing for distributed log storage.
    Uses virtual nodes to ensure even distribution across physical nodes.
    """
    
    def __init__(self, replica_count: int = 150):
        # Higher replica count means better distribution but more memory usage
        self.replica_count = replica_count
        
        # The ring maps hash positions to node IDs
        self.ring: Dict[int, str] = {}
        
        # Sorted list of positions for efficient binary search
        self.sorted_positions: List[int] = []
        
        # Track which nodes are in the ring
        self.nodes: set = set()
        
        # Statistics for monitoring
        self.stats = {
            'total_keys': 0,
            'rebalance_operations': 0,
            'node_additions': 0,
            'node_removals': 0
        }
    
    def _hash(self, key: str) -> int:
        """Generate consistent hash for a given key."""
        # Using SHA-1 for consistency with many production systems
        return int(hashlib.sha1(key.encode()).hexdigest(), 16)
    
    def _update_sorted_positions(self):
        """Maintain sorted list of ring positions for efficient lookups."""
        self.sorted_positions = sorted(self.ring.keys())
    
    def add_node(self, node_id: str) -> List[Tuple[int, int]]:
        """
        Add a node to the ring and return affected data ranges.
        Returns list of (start_pos, end_pos) tuples that need rebalancing.
        """
        if node_id in self.nodes:
            return []  # Node already exists
        
        affected_ranges = []
        
        # Add virtual nodes to distribute load evenly
        for i in range(self.replica_count):
            virtual_node_key = f"{node_id}:{i}"
            position = self._hash(virtual_node_key)
            
            # Find the range this new node will handle
            if self.sorted_positions:
                # Find successor node
                successor_idx = bisect.bisect_right(self.sorted_positions, position)
                if successor_idx == len(self.sorted_positions):
                    successor_pos = self.sorted_positions[0]  # Wrap around
                    # Range from position to end, then start to successor
                    affected_ranges.append((position, 2**160))  # Max hash value
                    affected_ranges.append((0, successor_pos))
                else:
                    successor_pos = self.sorted_positions[successor_idx]
                    affected_ranges.append((position, successor_pos))
            
            self.ring[position] = node_id
        
        self.nodes.add(node_id)
        self._update_sorted_positions()
        self.stats['node_additions'] += 1
        
        return affected_ranges
    
    def remove_node(self, node_id: str) -> List[Tuple[int, int]]:
        """Remove a node and return data ranges that need redistribution."""
        if node_id not in self.nodes:
            return []
        
        affected_ranges = []
        positions_to_remove = []
        
        # Find all virtual nodes for this physical node
        for position, node in self.ring.items():
            if node == node_id:
                positions_to_remove.append(position)
                
                # Find successor to determine data range
                successor_idx = bisect.bisect_right(self.sorted_positions, position)
                if successor_idx == len(self.sorted_positions):
                    successor_pos = self.sorted_positions[0]
                    affected_ranges.append((position, 2**160))
                    affected_ranges.append((0, successor_pos))
                else:
                    successor_pos = self.sorted_positions[successor_idx]
                    affected_ranges.append((position, successor_pos))
        
        # Remove all virtual nodes for this physical node
        for position in positions_to_remove:
            del self.ring[position]
        
        self.nodes.remove(node_id)
        self._update_sorted_positions()
        self.stats['node_removals'] += 1
        
        return affected_ranges
    
    def get_node(self, key: str) -> Optional[str]:
        """Find which node should handle the given key."""
        if not self.sorted_positions:
            return None
        
        hash_value = self._hash(key)
        
        # Find the first node clockwise from this position
        idx = bisect.bisect_right(self.sorted_positions, hash_value)
        if idx == len(self.sorted_positions):
            idx = 0  # Wrap around to first node
        
        return self.ring[self.sorted_positions[idx]]
    
    def get_nodes_for_replication(self, key: str, replica_count: int = 3) -> List[str]:
        """Get multiple nodes for data replication."""
        if not self.sorted_positions or replica_count <= 0:
            return []
        
        hash_value = self._hash(key)
        result_nodes = []
        seen_physical_nodes = set()
        
        # Start from the primary node position
        start_idx = bisect.bisect_right(self.sorted_positions, hash_value)
        if start_idx == len(self.sorted_positions):
            start_idx = 0
        
        # Collect unique physical nodes going clockwise
        for i in range(len(self.sorted_positions)):
            idx = (start_idx + i) % len(self.sorted_positions)
            position = self.sorted_positions[idx]
            node_id = self.ring[position]
            
            if node_id not in seen_physical_nodes:
                result_nodes.append(node_id)
                seen_physical_nodes.add(node_id)
                
                if len(result_nodes) >= replica_count:
                    break
        
        return result_nodes
    
    def get_load_distribution(self) -> Dict[str, float]:
        """Calculate theoretical load distribution across nodes."""
        if not self.sorted_positions:
            return {}
        
        node_ranges = defaultdict(int)
        
        for i, position in enumerate(self.sorted_positions):
            next_position = self.sorted_positions[(i + 1) % len(self.sorted_positions)]
            
            if next_position > position:
                range_size = next_position - position
            else:
                # Wrap around case
                range_size = (2**160 - position) + next_position
            
            node_id = self.ring[position]
            node_ranges[node_id] += range_size
        
        # Convert to percentages
        total_space = 2**160
        return {node: (size / total_space) * 100 for node, size in node_ranges.items()}
    
    def get_ring_state(self) -> dict:
        """Get complete ring state for debugging and monitoring."""
        return {
            'nodes': list(self.nodes),
            'virtual_nodes': len(self.sorted_positions),
            'replica_count': self.replica_count,
            'load_distribution': self.get_load_distribution(),
            'stats': self.stats
        }

# Test the implementation
if __name__ == "__main__":
    # Create a test ring
    ring = ConsistentHashRing(replica_count=100)
    
    # Add some nodes
    print("Adding nodes to ring...")
    ring.add_node("node-1")
    ring.add_node("node-2")
    ring.add_node("node-3")
    
    # Test key distribution
    test_keys = [f"log-{i}" for i in range(1000)]
    distribution = defaultdict(int)
    
    for key in test_keys:
        node = ring.get_node(key)
        distribution[node] += 1
    
    print("\nKey distribution:")
    for node, count in distribution.items():
        percentage = (count / len(test_keys)) * 100
        print(f"  {node}: {count} keys ({percentage:.1f}%)")
    
    print(f"\nRing state: {json.dumps(ring.get_ring_state(), indent=2)}")
