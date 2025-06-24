#!/bin/bash

# Day 29: Anti-Entropy Mechanisms Implementation Script
# Complete setup, build, test, and demonstration script

set -e  # Exit on any error

echo "🚀 Day 29: Anti-Entropy Mechanisms - Complete Implementation"
echo "============================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check Python installation
check_python() {
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 is required but not installed"
        exit 1
    fi
    print_success "Python3 found: $(python3 --version)"
}

# Create project structure
create_project_structure() {
    print_status "Creating project structure..."
    
    # Remove distributed_log_storage if it exists
    if [ -d "distributed_log_storage" ]; then
        rm -rf distributed_log_storage
    fi
    
    # Create base directory
    mkdir -p distributed_log_storage
    
    # Create all required directories
    mkdir -p distributed_log_storage/src/anti_entropy
    mkdir -p distributed_log_storage/src/storage
    mkdir -p distributed_log_storage/src/web/templates
    mkdir -p distributed_log_storage/tests/unit
    mkdir -p distributed_log_storage/tests/integration
    mkdir -p distributed_log_storage/config
    mkdir -p distributed_log_storage/data/node_a
    mkdir -p distributed_log_storage/data/node_b
    mkdir -p distributed_log_storage/data/node_c
    mkdir -p distributed_log_storage/logs
    mkdir -p distributed_log_storage/scripts
    mkdir -p distributed_log_storage/docs
    
    # Create __init__.py files directly
    touch distributed_log_storage/__init__.py
    touch distributed_log_storage/src/__init__.py
    touch distributed_log_storage/src/anti_entropy/__init__.py
    touch distributed_log_storage/src/storage/__init__.py
    touch distributed_log_storage/src/web/__init__.py
    touch distributed_log_storage/tests/__init__.py
    touch distributed_log_storage/tests/unit/__init__.py
    touch distributed_log_storage/tests/integration/__init__.py
    
    print_success "Project structure created"
}

# Create source files
create_source_files() {
    print_status "Creating source files..."
    
    # Merkle Tree Implementation
    cat > distributed_log_storage/src/anti_entropy/merkle_tree.py << 'EOF'
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
EOF

    # Anti-Entropy Coordinator
    cat > distributed_log_storage/src/anti_entropy/coordinator.py << 'EOF'
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
EOF

    # Read Repair Engine
    cat > distributed_log_storage/src/anti_entropy/read_repair.py << 'EOF'
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
EOF

    # Storage Node Implementation
    cat > distributed_log_storage/src/storage/node.py << 'EOF'
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
EOF

    # Web Dashboard
    cat > distributed_log_storage/src/web/dashboard.py << 'EOF'
from flask import Flask, render_template, jsonify, request
import json
import asyncio
from typing import Dict
import threading
import time

class AntiEntropyDashboard:
    """Web dashboard for monitoring anti-entropy operations"""
    
    def __init__(self, coordinator, nodes: Dict):
        self.app = Flask(__name__)
        self.coordinator = coordinator
        self.nodes = nodes
        self.setup_routes()
        
    def setup_routes(self):
        """Setup Flask routes"""
        
        @self.app.route('/')
        def index():
            return render_template('dashboard.html')
        
        @self.app.route('/api/metrics')
        def get_metrics():
            """Get current anti-entropy metrics"""
            return jsonify(self.coordinator.get_metrics())
        
        @self.app.route('/api/repair-queue')
        def get_repair_queue():
            """Get current repair queue status"""
            return jsonify(self.coordinator.get_repair_queue_status())
        
        @self.app.route('/api/nodes')
        def get_nodes():
            """Get node statistics"""
            node_stats = {}
            for node_id, node in self.nodes.items():
                node_stats[node_id] = node.get_stats()
            return jsonify(node_stats)
        
        @self.app.route('/api/trigger-scan', methods=['POST'])
        def trigger_scan():
            """Trigger immediate anti-entropy scan"""
            try:
                # Use threading to avoid blocking Flask
                def run_scan():
                    loop = asyncio.new_event_loop()
                    asyncio.set_event_loop(loop)
                    loop.run_until_complete(self.coordinator.trigger_immediate_scan())
                    loop.close()
                
                scan_thread = threading.Thread(target=run_scan)
                scan_thread.start()
                
                return jsonify({'success': True, 'message': 'Scan triggered'})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
        
        @self.app.route('/api/inject-inconsistency', methods=['POST'])
        def inject_inconsistency():
            """Inject artificial inconsistency for testing"""
            try:
                data = request.get_json()
                node_id = data.get('node_id')
                key = data.get('key', f'test_key_{int(time.time())}')
                value = data.get('value', f'inconsistent_value_{int(time.time())}')
                
                if node_id in self.nodes:
                    # Use threading for async operation
                    def inject():
                        loop = asyncio.new_event_loop()
                        asyncio.set_event_loop(loop)
                        loop.run_until_complete(self.nodes[node_id].put_entry(key, value))
                        loop.close()
                    
                    inject_thread = threading.Thread(target=inject)
                    inject_thread.start()
                    
                    return jsonify({
                        'success': True, 
                        'message': f'Inconsistency injected on {node_id}',
                        'key': key,
                        'value': value
                    })
                else:
                    return jsonify({'success': False, 'error': 'Node not found'})
                    
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})
    
    def run(self, host='127.0.0.1', port=5000, debug=False):
        """Run the dashboard"""
        self.app.run(host=host, port=port, debug=debug)
EOF

    # HTML Template
    mkdir -p distributed_log_storage/src/web/templates
    cat > distributed_log_storage/src/web/templates/dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Anti-Entropy Dashboard</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        
        .dashboard {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        h1 {
            color: white;
            text-align: center;
            margin-bottom: 30px;
            font-size: 2.5rem;
        }
        
        .card {
            background: white;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
        }
        
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .metric-card {
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            color: white;
            border-radius: 10px;
            padding: 20px;
            text-align: center;
        }
        
        .metric-value {
            font-size: 2rem;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .metric-label {
            font-size: 0.9rem;
            opacity: 0.9;
        }
        
        .controls {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }
        
        button {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 25px;
            cursor: pointer;
            font-weight: 600;
            transition: transform 0.2s;
        }
        
        button:hover {
            transform: translateY(-2px);
        }
        
        .status {
            padding: 10px;
            border-radius: 5px;
            margin: 10px 0;
        }
        
        .status.success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .status.error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .repair-queue, .node-stats {
            background: white;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 20px;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        
        th {
            background: #f8f9fa;
            font-weight: 600;
        }
        
        .inject-form {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
            align-items: center;
        }
        
        input, select {
            padding: 8px 12px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="dashboard">
        <h1>🔄 Anti-Entropy Dashboard</h1>
        
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-value" id="total-comparisons">0</div>
                <div class="metric-label">Total Comparisons</div>
            </div>
            <div class="metric-card">
                <div class="metric-value" id="inconsistencies">0</div>
                <div class="metric-label">Inconsistencies Detected</div>
            </div>
            <div class="metric-card">
                <div class="metric-value" id="repairs-completed">0</div>
                <div class="metric-label">Repairs Completed</div>
            </div>
            <div class="metric-card">
                <div class="metric-value" id="avg-repair-time">0.0s</div>
                <div class="metric-label">Avg Repair Time</div>
            </div>
        </div>
        
        <div class="card">
            <h3>Controls</h3>
            <div class="controls">
                <button onclick="triggerScan()">🔍 Trigger Immediate Scan</button>
                <button onclick="refreshData()">🔄 Refresh Data</button>
            </div>
            
            <h4>Inject Test Inconsistency</h4>
            <div class="inject-form">
                <select id="node-select">
                    <option value="node_a">Node A</option>
                    <option value="node_b">Node B</option>
                    <option value="node_c">Node C</option>
                </select>
                <input type="text" id="test-key" placeholder="Key (optional)" />
                <input type="text" id="test-value" placeholder="Value (optional)" />
                <button onclick="injectInconsistency()">💉 Inject Inconsistency</button>
            </div>
            
            <div id="status-messages"></div>
        </div>
        
        <div class="card">
            <h3>Repair Queue</h3>
            <div id="repair-queue">
                <table>
                    <thead>
                        <tr>
                            <th>Source</th>
                            <th>Target</th>
                            <th>Priority</th>
                            <th>Status</th>
                            <th>Created</th>
                        </tr>
                    </thead>
                    <tbody id="repair-queue-body">
                    </tbody>
                </table>
            </div>
        </div>
        
        <div class="card">
            <h3>Node Statistics</h3>
            <div id="node-stats">
                <table>
                    <thead>
                        <tr>
                            <th>Node ID</th>
                            <th>Entry Count</th>
                            <th>Last Update</th>
                        </tr>
                    </thead>
                    <tbody id="node-stats-body">
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        let refreshInterval;
        
        function showStatus(message, type = 'success') {
            const statusDiv = document.getElementById('status-messages');
            const statusElement = document.createElement('div');
            statusElement.className = `status ${type}`;
            statusElement.textContent = message;
            statusDiv.appendChild(statusElement);
            
            setTimeout(() => {
                statusElement.remove();
            }, 5000);
        }
        
        async function refreshData() {
            try {
                // Update metrics
                const metricsResponse = await fetch('/api/metrics');
                const metrics = await metricsResponse.json();
                
                document.getElementById('total-comparisons').textContent = metrics.total_comparisons || 0;
                document.getElementById('inconsistencies').textContent = metrics.inconsistencies_detected || 0;
                document.getElementById('repairs-completed').textContent = metrics.repairs_completed || 0;
                document.getElementById('avg-repair-time').textContent = `${(metrics.average_repair_time || 0).toFixed(2)}s`;
                
                // Update repair queue
                const queueResponse = await fetch('/api/repair-queue');
                const repairQueue = await queueResponse.json();
                
                const queueBody = document.getElementById('repair-queue-body');
                queueBody.innerHTML = '';
                
                repairQueue.forEach(task => {
                    const row = document.createElement('tr');
                    row.innerHTML = `
                        <td>${task.source_node}</td>
                        <td>${task.target_node}</td>
                        <td>${task.priority}</td>
                        <td>${task.status}</td>
                        <td>${new Date(task.created_at).toLocaleTimeString()}</td>
                    `;
                    queueBody.appendChild(row);
                });
                
                // Update node stats
                const nodesResponse = await fetch('/api/nodes');
                const nodeStats = await nodesResponse.json();
                
                const statsBody = document.getElementById('node-stats-body');
                statsBody.innerHTML = '';
                
                Object.entries(nodeStats).forEach(([nodeId, stats]) => {
                    const row = document.createElement('tr');
                    row.innerHTML = `
                        <td>${stats.node_id}</td>
                        <td>${stats.entry_count}</td>
                        <td>${new Date(stats.last_update).toLocaleTimeString()}</td>
                    `;
                    statsBody.appendChild(row);
                });
                
            } catch (error) {
                showStatus(`Error refreshing data: ${error.message}`, 'error');
            }
        }
        
        async function triggerScan() {
            try {
                const response = await fetch('/api/trigger-scan', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });
                
                const result = await response.json();
                if (result.success) {
                    showStatus('Anti-entropy scan triggered successfully!');
                } else {
                    showStatus(`Error: ${result.error}`, 'error');
                }
            } catch (error) {
                showStatus(`Error triggering scan: ${error.message}`, 'error');
            }
        }
        
        async function injectInconsistency() {
            try {
                const nodeId = document.getElementById('node-select').value;
                const key = document.getElementById('test-key').value;
                const value = document.getElementById('test-value').value;
                
                const response = await fetch('/api/inject-inconsistency', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        node_id: nodeId,
                        key: key || undefined,
                        value: value || undefined
                    })
                });
                
                const result = await response.json();
                if (result.success) {
                    showStatus(`Inconsistency injected: ${result.key} = ${result.value} on ${nodeId}`);
                    document.getElementById('test-key').value = '';
                    document.getElementById('test-value').value = '';
                } else {
                    showStatus(`Error: ${result.error}`, 'error');
                }
            } catch (error) {
                showStatus(`Error injecting inconsistency: ${error.message}`, 'error');
            }
        }
        
        // Auto-refresh every 5 seconds
        refreshInterval = setInterval(refreshData, 5000);
        
        // Initial load
        refreshData();
    </script>
</body>
</html>
EOF

    print_success "Source files created"
}

# Create test files
create_test_files() {
    print_status "Creating test files..."
    
    # Unit tests
    cat > distributed_log_storage/tests/unit/test_merkle_tree.py << 'EOF'
import unittest
from src.anti_entropy.merkle_tree import MerkleTree

class TestMerkleTree(unittest.TestCase):
    
    def test_empty_tree(self):
        tree = MerkleTree([])
        self.assertIsNone(tree.root)
        self.assertEqual(tree.get_root_hash(), "")
    
    def test_single_item_tree(self):
        tree = MerkleTree(["data1"])
        self.assertIsNotNone(tree.root)
        self.assertTrue(len(tree.get_root_hash()) > 0)
    
    def test_tree_comparison_identical(self):
        data = ["data1", "data2", "data3"]
        tree1 = MerkleTree(data)
        tree2 = MerkleTree(data)
        
        self.assertEqual(tree1.get_root_hash(), tree2.get_root_hash())
        differences = tree1.compare_with(tree2)
        self.assertEqual(len(differences), 0)
    
    def test_tree_comparison_different(self):
        tree1 = MerkleTree(["data1", "data2"])
        tree2 = MerkleTree(["data1", "data3"])
        
        self.assertNotEqual(tree1.get_root_hash(), tree2.get_root_hash())
        differences = tree1.compare_with(tree2)
        self.assertGreater(len(differences), 0)

if __name__ == '__main__':
    unittest.main()
EOF

    # Integration tests
    cat > distributed_log_storage/tests/integration/test_anti_entropy.py << 'EOF'
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
EOF

    # Main application
    cat > distributed_log_storage/main.py << 'EOF'
import asyncio
import logging
import threading
import time
from src.storage.node import StorageNode
from src.anti_entropy.coordinator import AntiEntropyCoordinator
from src.anti_entropy.read_repair import ReadRepairEngine
from src.web.dashboard import AntiEntropyDashboard

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

async def simulate_workload(nodes):
    """Simulate some log processing workload"""
    print("🔄 Starting workload simulation...")
    
    for i in range(10):
        # Add entries to random nodes (simulating distributed writes)
        node_names = list(nodes.keys())
        
        # Add to all nodes (consistent)
        for node_name in node_names:
            await nodes[node_name].put_entry(f'consistent_key_{i}', f'value_{i}')
        
        # Add to only some nodes (create inconsistencies)
        if i % 3 == 0:
            await nodes['node_a'].put_entry(f'inconsistent_key_{i}', f'value_a_{i}')
        elif i % 3 == 1:
            await nodes['node_b'].put_entry(f'inconsistent_key_{i}', f'value_b_{i}')
        
        await asyncio.sleep(1)
    
    print("✅ Workload simulation completed")

async def main():
    """Main application entry point"""
    print("🚀 Starting Distributed Log Storage with Anti-Entropy")
    print("=" * 60)
    
    # Create storage nodes
    nodes = {
        'node_a': StorageNode('node_a', 'data/node_a'),
        'node_b': StorageNode('node_b', 'data/node_b'),
        'node_c': StorageNode('node_c', 'data/node_c')
    }
    
    # Create anti-entropy coordinator
    coordinator = AntiEntropyCoordinator(nodes, scan_interval=10)
    
    # Create read repair engine
    read_repair = ReadRepairEngine(nodes)
    
    # Create and start web dashboard in separate thread
    dashboard = AntiEntropyDashboard(coordinator, nodes)
    dashboard_thread = threading.Thread(
        target=lambda: dashboard.run(host='127.0.0.1', port=5000, debug=False)
    )
    dashboard_thread.daemon = True
    dashboard_thread.start()
    
    print("🌐 Web dashboard started at http://127.0.0.1:5000")
    
    # Start workload simulation
    workload_task = asyncio.create_task(simulate_workload(nodes))
    
    # Start anti-entropy coordinator
    coordinator_task = asyncio.create_task(coordinator.start())
    
    print("🔄 Anti-entropy coordinator started")
    print("📊 Monitor progress at: http://127.0.0.1:5000")
    print("Press Ctrl+C to stop...")
    
    try:
        # Wait for workload to complete
        await workload_task
        
        # Continue running coordinator and dashboard
        await coordinator_task
        
    except KeyboardInterrupt:
        print("\n🛑 Shutting down...")
        await coordinator.stop()

if __name__ == "__main__":
    asyncio.run(main())
EOF

    # Requirements
    cat > distributed_log_storage/requirements.txt << 'EOF'
flask==2.3.3
pytest==7.4.0
pytest-asyncio==0.21.1
EOF

    # Configuration
    cat > distributed_log_storage/config/anti_entropy.yaml << 'EOF'
anti_entropy:
  scan_interval: 30  # seconds
  repair_timeout: 10  # seconds
  max_concurrent_repairs: 3
  consistency_threshold: 0.7  # 70% agreement required

nodes:
  node_a:
    port: 8001
    data_dir: "data/node_a"
  node_b:
    port: 8002
    data_dir: "data/node_b"
  node_c:
    port: 8003
    data_dir: "data/node_c"

logging:
  level: INFO
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
EOF

    # Docker files
    cat > distributed_log_storage/Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Create data directories
RUN mkdir -p data/node_a data/node_b data/node_c logs

# Expose port
EXPOSE 5000

# Run application
CMD ["python", "main.py"]
EOF

    cat > distributed_log_storage/docker-compose.yml << 'EOF'
version: '3.8'

services:
  anti-entropy-system:
    build: .
    ports:
      - "5000:5000"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    environment:
      - PYTHONPATH=/app
    restart: unless-stopped
    
  # Optional: Add monitoring
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
EOF

    print_success "Test files and configuration created"
}

# Create build and run scripts
create_scripts() {
    print_status "Creating build and run scripts..."
    
    # Build script
    cat > distributed_log_storage/scripts/build.sh << 'EOF'
#!/bin/bash

echo "🔨 Building Anti-Entropy System..."

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Create necessary directories
mkdir -p data/{node_a,node_b,node_c} logs

echo "✅ Build completed successfully!"
echo "Run: source venv/bin/activate && python main.py"
EOF

    # Test script
    cat > distributed_log_storage/scripts/test.sh << 'EOF'
#!/bin/bash

echo "🧪 Running Anti-Entropy Tests..."

# Activate virtual environment
source venv/bin/activate

# Run unit tests
echo "Running unit tests..."
python -m pytest tests/unit/ -v

# Run integration tests
echo "Running integration tests..."
python -m pytest tests/integration/ -v

echo "✅ All tests completed!"
EOF

    # Docker build script
    cat > distributed_log_storage/scripts/docker_build.sh << 'EOF'
#!/bin/bash

echo "🐳 Building Docker Image..."

# Build Docker image
docker build -t anti-entropy-system .

# Run with docker-compose
docker-compose up --build

echo "✅ Docker build completed!"
echo "Access dashboard at: http://localhost:5000"
EOF

    chmod +x distributed_log_storage/scripts/*.sh
    
    print_success "Build and run scripts created"
}

# Run tests
run_tests() {
    print_status "Running tests..."
    
    cd distributed_log_storage
    
    # Create virtual environment and install dependencies
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # Run unit tests
    print_status "Running unit tests..."
    python -m pytest tests/unit/ -v
    
    # Run integration tests  
    print_status "Running integration tests..."
    python -m pytest tests/integration/ -v
    
    cd ..
    
    print_success "All tests passed!"
}

# Start demonstration
start_demo() {
    print_status "Starting demonstration..."
    
    cd distributed_log_storage
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Start the application
    print_success "🚀 Starting Anti-Entropy System Demo"
    print_success "Dashboard will be available at: http://127.0.0.1:5000"
    print_success "Press Ctrl+C to stop the demo"
    
    python main.py
}

# Main execution
main() {
    print_status "Day 29: Anti-Entropy Mechanisms - Complete Implementation"
    echo ""
    
    check_python
    create_project_structure
    create_source_files
    create_test_files
    create_scripts
    
    print_success "✅ Project setup completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "1. cd distributed_log_storage"
    echo "2. source venv/bin/activate"
    echo "3. python main.py"
    echo ""
    print_status "Or run with Docker:"
    echo "1. cd distributed_log_storage"
    echo "2. docker-compose up --build"
    echo ""
    
    # Ask user if they want to run tests and demo
    read -p "Would you like to run tests now? (y/N): " run_tests_choice
    if [[ $run_tests_choice =~ ^[Yy]$ ]]; then
        run_tests
    fi
    
    read -p "Would you like to start the demonstration? (y/N): " demo_choice
    if [[ $demo_choice =~ ^[Yy]$ ]]; then
        start_demo
    fi
    
    print_success "🎉 Anti-Entropy implementation completed!"
}

# Run main function
main "$@"