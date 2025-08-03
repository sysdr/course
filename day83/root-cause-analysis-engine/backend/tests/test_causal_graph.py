"""
Tests for Causal Graph Builder
"""

import pytest
from datetime import datetime, timedelta
from src.analyzers.causal_graph import CausalGraphBuilder
from src.models.log_event import LogEvent

@pytest.fixture
def graph_builder():
    return CausalGraphBuilder()

@pytest.fixture
def service_dependencies():
    return {
        "api-gateway": ["auth-service", "database"],
        "auth-service": ["database"],
        "database": []
    }

@pytest.fixture
def test_events():
    base_time = datetime.now()
    return [
        LogEvent(
            id="e1", timestamp=base_time, service="database",
            level="ERROR", message="Connection timeout"
        ),
        LogEvent(
            id="e2", timestamp=base_time + timedelta(seconds=30),
            service="auth-service", level="ERROR", message="Auth failed"
        ),
        LogEvent(
            id="e3", timestamp=base_time + timedelta(seconds=60),
            service="api-gateway", level="WARNING", message="High latency"
        )
    ]

def test_build_graph(graph_builder, test_events, service_dependencies):
    """Test basic graph construction"""
    graph = graph_builder.build_graph(test_events, service_dependencies)
    
    assert graph.number_of_nodes() == 3
    assert all(event.id in graph.nodes() for event in test_events)

def test_causal_relationships(graph_builder, test_events, service_dependencies):
    """Test causal relationship detection"""
    graph = graph_builder.build_graph(test_events, service_dependencies)
    
    # Database error should cause auth service error
    assert graph.has_edge("e1", "e2") or graph.has_edge("e2", "e1")

def test_causal_strength_calculation(graph_builder, test_events, service_dependencies):
    """Test causal strength calculation"""
    event1 = test_events[0]  # Database error
    event2 = test_events[1]  # Auth error (dependent on database)
    
    strength = graph_builder._calculate_causal_strength(
        event1, event2, service_dependencies
    )
    
    assert 0.1 <= strength <= 1.0
    assert strength > 0.5  # Should be high due to dependency

def test_temporal_constraints(graph_builder, service_dependencies):
    """Test temporal constraints in causal relationships"""
    base_time = datetime.now()
    
    # Events too far apart
    event1 = LogEvent(
        id="e1", timestamp=base_time, service="database", 
        level="ERROR", message="Error"
    )
    event2 = LogEvent(
        id="e2", timestamp=base_time + timedelta(hours=1),
        service="auth-service", level="ERROR", message="Error"
    )
    
    # Should not be considered causal due to time gap
    assert not graph_builder._is_causal_relationship(
        event1, event2, service_dependencies
    )
