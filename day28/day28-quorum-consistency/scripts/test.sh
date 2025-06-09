#!/bin/bash

echo "🧪 Running Quorum System Tests..."

# Unit tests
python -m pytest tests/test_quorum.py -v

# Integration test
python -c "
import asyncio
from src.consistency_manager import ConsistencyManager, ConsistencyLevel

async def integration_test():
    manager = ConsistencyManager()
    nodes = ['node1', 'node2', 'node3', 'node4', 'node5']
    
    print('Setting up cluster...')
    await manager.setup_cluster(nodes, ConsistencyLevel.BALANCED)
    
    print('Testing write operations...')
    for i in range(5):
        result = await manager.write_with_quorum(f'key{i}', f'value{i}')
        print(f'Write {i}: {result[\"success\"]}')
    
    print('Testing read operations...')
    for i in range(5):
        result = await manager.read_with_quorum(f'key{i}')
        print(f'Read {i}: {result[\"success\"]}')
    
    print('Testing consistency level changes...')
    await manager.change_consistency_level(ConsistencyLevel.STRONG)
    result = await manager.write_with_quorum('strong_key', 'strong_value')
    print(f'Strong consistency write: {result[\"success\"]}')
    
    print('Metrics:', manager.get_metrics())
    await manager.shutdown()
    print('✅ Integration test completed')

asyncio.run(integration_test())
"

echo "✅ All tests completed"
