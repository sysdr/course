import asyncio
import json
import os
from typing import Dict, List, Optional, Any
from datetime import datetime
import hashlib
from dataclasses import dataclass, asdict

from ..anti_entropy.merkle_tree import MerkleTree

@dataclass
class LogEntry:
    """Represents a log entry"""
    key: str
    value: str
    timestamp: datetime
    version: int = 1
    
    def to_dict(self) -> Dict:
        return {
            'key': self.key,
            'value': self.value,
            'timestamp': self.timestamp.isoformat(),
            'version': self.version
        }
    
    @classmethod
    def from_dict(cls, data: Dict) -> 'LogEntry':
        return cls(
            key=data['key'],
            value=data['value'],
            timestamp=datetime.fromisoformat(data['timestamp']),
            version=data.get('version', 1)
        )

class StorageNode:
    """Distributed storage node with anti-entropy support"""
    
    def __init__(self, node_id: str, data_dir: str):
        self.node_id = node_id
        self.data_dir = data_dir
        self.entries: Dict[str, LogEntry] = {}
        self._ensure_data_dir()
        self._load_data()
        
    def _ensure_data_dir(self):
        """Ensure data directory exists"""
        os.makedirs(self.data_dir, exist_ok=True)
        
    def _load_data(self):
        """Load existing data from disk"""
        data_file = os.path.join(self.data_dir, 'entries.json')
        if os.path.exists(data_file):
            try:
                with open(data_file, 'r') as f:
                    data = json.load(f)
                    for key, entry_data in data.items():
                        self.entries[key] = LogEntry.from_dict(entry_data)
            except Exception as e:
                print(f"Error loading data for {self.node_id}: {e}")
    
    def _save_data(self):
        """Save data to disk"""
        data_file = os.path.join(self.data_dir, 'entries.json')
        try:
            data = {key: entry.to_dict() for key, entry in self.entries.items()}
            with open(data_file, 'w') as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"Error saving data for {self.node_id}: {e}")
    
    async def put_entry(self, key: str, value: str) -> bool:
        """Store a log entry"""
        try:
            existing = self.entries.get(key)
            version = existing.version + 1 if existing else 1
            
            entry = LogEntry(
                key=key,
                value=value,
                timestamp=datetime.now(),
                version=version
            )
            
            self.entries[key] = entry
            self._save_data()
            return True
            
        except Exception as e:
            print(f"Error putting entry {key} on {self.node_id}: {e}")
            return False
    
    async def get_entry(self, key: str) -> Optional[LogEntry]:
        """Retrieve a log entry"""
        return self.entries.get(key)
    
    async def get_entry_count(self) -> int:
        """Get total number of entries"""
        return len(self.entries)
    
    async def get_keys_in_range(self, start_key: str, end_key: str) -> List[str]:
        """Get keys in specified range"""
        return [key for key in self.entries.keys() if start_key <= key <= end_key]
    
    async def get_merkle_tree(self) -> MerkleTree:
        """Generate Merkle tree for current data"""
        # Create data blocks from entries
        data_blocks = []
        for key in sorted(self.entries.keys()):
            entry = self.entries[key]
            block_data = f"{key}:{entry.value}:{entry.timestamp.isoformat()}:{entry.version}"
            data_blocks.append(block_data)
        
        return MerkleTree(data_blocks)
    
    async def get_missing_entries(self, missing_data_refs: List[str]) -> List[LogEntry]:
        """Get entries that are missing on other nodes"""
        missing_entries = []
        
        for ref in missing_data_refs:
            # Extract key from reference (simplified)
            if ':' in ref:
                key = ref.split(':')[0].split('/')[-1]
                if key in self.entries:
                    missing_entries.append(self.entries[key])
        
        return missing_entries
    
    async def repair_entry(self, entry: LogEntry) -> bool:
        """Repair/update an entry during anti-entropy"""
        try:
            existing = self.entries.get(entry.key)
            
            # Only update if the repair entry is newer
            if not existing or entry.timestamp > existing.timestamp:
                self.entries[entry.key] = entry
                self._save_data()
                return True
            
            return False
            
        except Exception as e:
            print(f"Error repairing entry {entry.key} on {self.node_id}: {e}")
            return False
    
    def get_stats(self) -> Dict:
        """Get node statistics"""
        return {
            'node_id': self.node_id,
            'entry_count': len(self.entries),
            'data_dir': self.data_dir,
            'last_update': max((e.timestamp for e in self.entries.values()), default=datetime.now()).isoformat()
        }
