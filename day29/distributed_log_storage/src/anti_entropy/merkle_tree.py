import hashlib
import json
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime

@dataclass
class MerkleNode:
    """Represents a node in the Merkle tree"""
    hash_value: str
    left: Optional['MerkleNode'] = None
    right: Optional['MerkleNode'] = None
    data: Optional[str] = None
    level: int = 0

class MerkleTree:
    """Efficient Merkle tree implementation for anti-entropy"""
    
    def __init__(self, data_blocks: List[str]):
        self.data_blocks = data_blocks
        self.root = self._build_tree()
        
    def _hash(self, data: str) -> str:
        """Create SHA-256 hash of data"""
        return hashlib.sha256(data.encode()).hexdigest()
    
    def _build_tree(self) -> Optional[MerkleNode]:
        """Build Merkle tree from data blocks"""
        if not self.data_blocks:
            return None
            
        # Create leaf nodes
        nodes = [MerkleNode(
            hash_value=self._hash(block),
            data=block,
            level=0
        ) for block in self.data_blocks]
        
        level = 1
        while len(nodes) > 1:
            next_level = []
            
            # Process pairs of nodes
            for i in range(0, len(nodes), 2):
                left = nodes[i]
                right = nodes[i + 1] if i + 1 < len(nodes) else left
                
                combined_hash = self._hash(left.hash_value + right.hash_value)
                parent = MerkleNode(
                    hash_value=combined_hash,
                    left=left,
                    right=right,
                    level=level
                )
                next_level.append(parent)
            
            nodes = next_level
            level += 1
            
        return nodes[0] if nodes else None
    
    def get_root_hash(self) -> str:
        """Get root hash of the tree"""
        return self.root.hash_value if self.root else ""
    
    def get_proof(self, data_block: str) -> List[Tuple[str, str]]:
        """Get Merkle proof for a data block"""
        proof = []
        
        def find_path(node: MerkleNode, target_hash: str, path: List[Tuple[str, str]]) -> bool:
            if not node:
                return False
                
            if node.data and self._hash(node.data) == target_hash:
                return True
                
            if node.left and find_path(node.left, target_hash, path):
                if node.right:
                    path.append((node.right.hash_value, "right"))
                return True
                
            if node.right and find_path(node.right, target_hash, path):
                if node.left:
                    path.append((node.left.hash_value, "left"))
                return True
                
            return False
        
        target_hash = self._hash(data_block)
        find_path(self.root, target_hash, proof)
        return proof
    
    def compare_with(self, other_tree: 'MerkleTree') -> List[str]:
        """Compare with another Merkle tree and return differences"""
        differences = []
        
        def compare_nodes(node1: Optional[MerkleNode], node2: Optional[MerkleNode], path: str = ""):
            if not node1 and not node2:
                return
            
            if not node1 or not node2 or node1.hash_value != node2.hash_value:
                if node1 and node1.data:
                    differences.append(f"{path}: {node1.data}")
                if node2 and node2.data:
                    differences.append(f"{path}: {node2.data}")
                    
                if node1 and node2:
                    compare_nodes(node1.left, node2.left, f"{path}/L")
                    compare_nodes(node1.right, node2.right, f"{path}/R")
        
        compare_nodes(self.root, other_tree.root)
        return differences
    
    def to_dict(self) -> Dict:
        """Convert tree to dictionary for serialization"""
        def node_to_dict(node: Optional[MerkleNode]) -> Optional[Dict]:
            if not node:
                return None
            return {
                "hash": node.hash_value,
                "data": node.data,
                "level": node.level,
                "left": node_to_dict(node.left),
                "right": node_to_dict(node.right)
            }
        
        return {
            "root": node_to_dict(self.root),
            "data_blocks": self.data_blocks,
            "created_at": datetime.now().isoformat()
        }
