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
