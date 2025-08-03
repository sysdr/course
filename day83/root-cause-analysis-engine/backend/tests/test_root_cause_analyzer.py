"""
Tests for Root Cause Analyzer
"""

import pytest
import asyncio
from datetime import datetime, timedelta
from src.analyzers.root_cause_analyzer import RootCauseAnalyzer
from src.models.log_event import LogEvent

@pytest.fixture
def analyzer():
    return RootCauseAnalyzer()

@pytest.fixture
def sample_events():
    base_time = datetime.now()
    return [
        LogEvent(
            id="test_001",
            timestamp=base_time,
            service="database",
            level="ERROR",
            message="Connection failed",
            metadata={"error_code": "CONN_TIMEOUT"}
        ),
        LogEvent(
            id="test_002",
            timestamp=base_time + timedelta(seconds=30),
            service="api-gateway",
            level="WARNING",
            message="High latency detected",
            metadata={"latency_ms": 3000}
        ),
        LogEvent(
            id="test_003",
            timestamp=base_time + timedelta(seconds=60),
            service="auth-service",
            level="ERROR",
            message="Authentication failed",
            metadata={"error_code": "DB_UNAVAILABLE"}
        )
    ]

@pytest.mark.asyncio
async def test_analyze_incident(analyzer, sample_events):
    """Test incident analysis produces valid report"""
    report = await analyzer.analyze_incident(sample_events)
    
    assert report.incident_id is not None
    assert len(report.events) == 3
    assert len(report.root_causes) > 0
    assert report.timeline is not None
    assert report.impact_analysis is not None

@pytest.mark.asyncio
async def test_root_cause_identification(analyzer, sample_events):
    """Test that root causes are properly identified"""
    report = await analyzer.analyze_incident(sample_events)
    
    # Should identify database error as primary root cause
    top_root_cause = report.root_causes[0]
    assert top_root_cause.service == "database"
    assert top_root_cause.confidence > 0.5

def test_events_are_related(analyzer):
    """Test causal relationship detection"""
    base_time = datetime.now()
    
    event1 = LogEvent(
        id="e1", timestamp=base_time, service="database", 
        level="ERROR", message="DB error"
    )
    event2 = LogEvent(
        id="e2", timestamp=base_time + timedelta(seconds=30),
        service="api-gateway", level="WARNING", message="High latency"
    )
    
    # Database error should relate to API gateway issues
    assert analyzer._events_are_related(event1, event2)

def test_trace_impact(analyzer, sample_events):
    """Test impact tracing functionality"""
    db_event = sample_events[0]  # Database error
    affected_services = analyzer._trace_impact(db_event, sample_events)
    
    assert "database" in affected_services
    assert len(affected_services) >= 1

@pytest.mark.asyncio
async def test_causal_graph_generation(analyzer, sample_events):
    """Test causal graph is properly generated"""
    report = await analyzer.analyze_incident(sample_events)
    graph_data = analyzer.get_causal_graph(report.incident_id)
    
    assert graph_data is not None
    assert "nodes" in graph_data
    assert "edges" in graph_data
    assert len(graph_data["nodes"]) == 3
