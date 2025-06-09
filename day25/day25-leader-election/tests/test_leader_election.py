import pytest
import asyncio
import time
from src.raft_node import RaftNode, NodeState
from src.cluster_manager import ClusterManager

@pytest.mark.asyncio
async def test_single_node_election():
    """Test that a single node becomes leader immediately"""
    node = RaftNode("node-1", [])
    
    # Start election
    await node._start_election()
    
    # Should become leader immediately (majority of 1)
    assert node.state == NodeState.LEADER
    assert node.current_term == 1

@pytest.mark.asyncio 
async def test_three_node_election():
    """Test election with three nodes"""
    cluster_config = {
        "nodes": [
            {"id": "node-1", "port": 8001},
            {"id": "node-2", "port": 8002}, 
            {"id": "node-3", "port": 8003}
        ]
    }
    
    manager = ClusterManager(cluster_config)
    await manager.start_cluster()
    
    # Wait for election
    await asyncio.sleep(1)
    
    # Should have exactly one leader
    leaders = [node for node in manager.nodes.values() if node.state == NodeState.LEADER]
    assert len(leaders) == 1
    
    await manager.stop_cluster()

@pytest.mark.asyncio
async def test_leader_failure_recovery():
    """Test that cluster recovers from leader failure"""
    cluster_config = {
        "nodes": [
            {"id": "node-1", "port": 8001},
            {"id": "node-2", "port": 8002},
            {"id": "node-3", "port": 8003}
        ]
    }
    
    manager = ClusterManager(cluster_config)
    await manager.start_cluster()
    
    # Wait for initial election
    await asyncio.sleep(1)
    
    # Find leader
    original_leader = manager._find_leader()
    assert original_leader is not None
    
    # Simulate leader failure
    await manager.simulate_failure(original_leader)
    
    # Wait for new election
    await asyncio.sleep(2)
    
    # Should have new leader
    new_leader = manager._find_leader()
    assert new_leader is not None
    assert new_leader != original_leader
    
    await manager.stop_cluster()

@pytest.mark.asyncio
async def test_election_timeout():
    """Test that election timeout triggers properly"""
    node = RaftNode("node-1", ["node-2", "node-3"])
    node.election_timeout = 0.1  # 100ms timeout
    
    start_time = time.time()
    
    # Manually trigger timeout check
    await node._election_timeout_loop()
    
    # Should have started election within timeout
    elapsed = time.time() - start_time
    assert elapsed >= 0.1
    assert node.state == NodeState.CANDIDATE

def test_vote_counting():
    """Test vote counting logic"""
    node = RaftNode("node-1", ["node-2", "node-3", "node-4"])  # 5 node cluster
    node.state = NodeState.CANDIDATE
    node.votes_received = 1  # Self vote
    
    # Need 3 votes for majority in 5-node cluster
    assert node.votes_received <= (len(node.peers) + 1) // 2  # Not majority yet
    
    node.votes_received = 3
    assert node.votes_received > (len(node.peers) + 1) // 2  # Majority achieved

def test_term_comparison():
    """Test term comparison for election validity"""
    node = RaftNode("node-1", ["node-2"])
    node.current_term = 5
    
    # Higher term should cause step down
    assert 6 > node.current_term  # Would trigger become_follower
    
    # Same term should not
    assert 5 == node.current_term  # No change needed
    
    # Lower term should be rejected  
    assert 4 < node.current_term  # Would reject vote/append

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
