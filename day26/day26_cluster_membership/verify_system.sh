#!/bin/bash
echo "=== Running comprehensive system verification ==="

# Activate virtual environment
source venv/bin/activate

# Set PYTHONPATH
export PYTHONPATH=$PWD

# Run all tests
python -m pytest tests/

# Run system checks
python -c "
import asyncio
import platform
from src.cluster_member import ClusterMember
from src.cluster_manager import ClusterManager

async def verify_system():
    print(f'Running on {platform.system()} {platform.release()} ({platform.machine()})')
    
    manager = ClusterManager()
    member1 = await manager.add_member('node1', 'localhost', 8000)
    member2 = await manager.add_member('node2', 'localhost', 8001)
    
    assert len(manager.members) == 2
    print('System verification passed!')

asyncio.run(verify_system())
"

echo "=== System verification completed successfully ==="
