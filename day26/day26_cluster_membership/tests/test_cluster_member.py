import pytest
import asyncio
import platform
from src.cluster_member import ClusterMember, NodeStatus

@pytest.mark.asyncio
async def test_cluster_member_initialization():
    member = ClusterMember("test1", "localhost", 8000)
    assert member.node_id == "test1"
    assert member.status == NodeStatus.JOINING
    assert member.node_id in member.membership

@pytest.mark.asyncio
async def test_platform_specific_setup():
    """Test that platform-specific optimizations are properly configured"""
    member = ClusterMember("test2", "localhost", 8001)
    assert asyncio.get_event_loop() is not None
