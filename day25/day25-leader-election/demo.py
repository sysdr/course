import asyncio
import time
import json
from src.cluster_manager import ClusterManager

async def main():
    """Main demo of leader election"""
    print("🚀 Raft Leader Election Demo")
    print("=" * 50)
    
    # Cluster configuration
    cluster_config = {
        "nodes": [
            {"id": "node-1", "port": 8001},
            {"id": "node-2", "port": 8002},
            {"id": "node-3", "port": 8003},
            {"id": "node-4", "port": 8004},
            {"id": "node-5", "port": 8005}
        ]
    }
    
    # Create and start cluster
    manager = ClusterManager(cluster_config)
    await manager.start_cluster()
    
    print("\n📊 Initial cluster status:")
    await asyncio.sleep(2)  # Wait for initial election
    print_status(manager.get_cluster_status())
    
    print("\n💥 Simulating leader failure...")
    leader = manager._find_leader()
    if leader:
        await manager.simulate_failure(leader)
        await asyncio.sleep(3)  # Wait for re-election
        
        print("\n📊 Status after leader failure:")
        print_status(manager.get_cluster_status())
    
    print("\n🔄 Recovering failed node...")
    if leader:
        await manager.recover_node(leader)
        await asyncio.sleep(2)
        
        print("\n📊 Final cluster status:")
        print_status(manager.get_cluster_status())
    
    print("\n✅ Demo completed! Check web/index.html for interactive demo")
    await manager.stop_cluster()

def print_status(status):
    """Print cluster status in a readable format"""
    print(f"Cluster Size: {status['cluster_size']}")
    print(f"Current Leader: {status['leader'] or 'None'}")
    print("\nNode States:")
    
    for node_id, node_info in status['nodes'].items():
        state_emoji = {"leader": "👑", "candidate": "🗳️", "follower": "👥"}
        emoji = state_emoji.get(node_info['state'], "❓")
        print(f"  {emoji} {node_id}: {node_info['state']} (term {node_info['term']})")

if __name__ == "__main__":
    asyncio.run(main())
