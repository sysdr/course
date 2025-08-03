"""
Root Cause Analysis Engine
Main analyzer that coordinates causal inference and root cause ranking
"""

import asyncio
import uuid
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import json
import numpy as np
from collections import defaultdict

from models.log_event import LogEvent, IncidentReport, RootCause
from analyzers.causal_graph import CausalGraphBuilder
from analyzers.timeline_reconstructor import TimelineReconstructor
from utils.confidence_scorer import ConfidenceScorer

class RootCauseAnalyzer:
    def __init__(self):
        self.causal_graph_builder = CausalGraphBuilder()
        self.timeline_reconstructor = TimelineReconstructor()
        self.confidence_scorer = ConfidenceScorer()
        self.incident_history: List[IncidentReport] = []
        self.active_incidents: Dict[str, IncidentReport] = {}
        
        # Service dependency mapping (simulated)
        self.service_dependencies = {
            "api-gateway": ["auth-service", "user-service", "payment-service"],
            "auth-service": ["database", "redis-cache"],
            "user-service": ["database", "file-storage"],
            "payment-service": ["database", "external-payment-api"],
            "database": [],
            "redis-cache": [],
            "file-storage": [],
            "external-payment-api": []
        }
    
    async def initialize_sample_data(self):
        """Initialize with sample incident data for demonstration"""
        sample_events = [
            LogEvent(
                id="evt_001",
                timestamp=datetime.now() - timedelta(minutes=5),
                service="database",
                level="ERROR",
                message="Connection timeout after 30 seconds",
                metadata={"error_code": "TIMEOUT", "connection_pool": "main"}
            ),
            LogEvent(
                id="evt_002", 
                timestamp=datetime.now() - timedelta(minutes=4, seconds=30),
                service="api-gateway",
                level="WARNING",
                message="Increased response latency detected",
                metadata={"avg_latency": "2.5s", "threshold": "1.0s"}
            ),
            LogEvent(
                id="evt_003",
                timestamp=datetime.now() - timedelta(minutes=4),
                service="auth-service", 
                level="ERROR",
                message="Authentication request failed",
                metadata={"error_code": "DB_UNAVAILABLE", "user_id": "12345"}
            ),
            LogEvent(
                id="evt_004",
                timestamp=datetime.now() - timedelta(minutes=3, seconds=45),
                service="user-service",
                level="ERROR", 
                message="Failed to retrieve user profile",
                metadata={"error_code": "DB_CONNECTION_FAILED", "user_id": "12345"}
            )
        ]
        
        # Analyze the sample incident
        sample_report = await self.analyze_incident(sample_events)
        print(f"✅ Sample incident analyzed: {sample_report.incident_id}")
    
    async def analyze_incident(self, events: List[LogEvent]) -> IncidentReport:
        """Perform comprehensive root cause analysis on incident events"""
        incident_id = str(uuid.uuid4())[:8]
        
        # Step 1: Reconstruct timeline
        timeline = self.timeline_reconstructor.reconstruct(events)
        
        # Step 2: Build causal graph
        causal_graph = self.causal_graph_builder.build_graph(events, self.service_dependencies)
        
        # Step 3: Identify potential root causes
        root_causes = await self._identify_root_causes(events, causal_graph)
        
        # Step 4: Calculate confidence scores
        for root_cause in root_causes:
            root_cause.confidence = self.confidence_scorer.calculate_confidence(
                root_cause, events, causal_graph
            )
        
        # Step 5: Rank by confidence
        root_causes.sort(key=lambda x: x.confidence, reverse=True)
        
        # Step 6: Generate impact analysis
        impact_analysis = self._analyze_impact(events, causal_graph)
        
        # Create incident report
        report = IncidentReport(
            incident_id=incident_id,
            timestamp=datetime.now(),
            events=events,
            timeline=timeline,
            root_causes=root_causes,
            impact_analysis=impact_analysis,
            causal_graph_summary=self._summarize_graph(causal_graph)
        )
        
        # Store the incident
        self.incident_history.append(report)
        self.active_incidents[incident_id] = report
        
        return report
    
    async def _identify_root_causes(self, events: List[LogEvent], causal_graph) -> List[RootCause]:
        """Identify potential root causes from events and causal relationships"""
        root_causes = []
        
        # Find events with no incoming edges (potential root causes)
        root_candidates = []
        for event in events:
            has_incoming = any(
                self._events_are_related(other, event) and other.timestamp < event.timestamp
                for other in events if other.id != event.id
            )
            if not has_incoming or event.level == "ERROR":
                root_candidates.append(event)
        
        # Create root cause objects
        for event in root_candidates:
            affected_services = self._trace_impact(event, events)
            
            root_cause = RootCause(
                event_id=event.id,
                service=event.service,
                description=event.message,
                timestamp=event.timestamp,
                confidence=0.0,  # Will be calculated later
                affected_services=affected_services,
                evidence=[f"Event occurred at {event.timestamp}", f"Service: {event.service}", f"Level: {event.level}"]
            )
            root_causes.append(root_cause)
        
        return root_causes
    
    def _events_are_related(self, event1: LogEvent, event2: LogEvent) -> bool:
        """Determine if two events are causally related"""
        # Time window check (events must be within 5 minutes)
        time_diff = abs((event1.timestamp - event2.timestamp).total_seconds())
        if time_diff > 300:  # 5 minutes
            return False
        
        # Service dependency check
        if event1.service in self.service_dependencies:
            if event2.service in self.service_dependencies[event1.service]:
                return True
        
        # Error propagation patterns
        if event1.level == "ERROR" and event2.level in ["ERROR", "WARNING"]:
            return True
        
        return False
    
    def _trace_impact(self, root_event: LogEvent, all_events: List[LogEvent]) -> List[str]:
        """Trace which services were affected by a root cause event"""
        affected = set([root_event.service])
        
        # Find downstream services that reported issues after the root event
        for event in all_events:
            if (event.timestamp > root_event.timestamp and 
                event.level in ["ERROR", "WARNING"] and
                self._events_are_related(root_event, event)):
                affected.add(event.service)
        
        return list(affected)
    
    def _analyze_impact(self, events: List[LogEvent], causal_graph) -> Dict[str, Any]:
        """Analyze the overall impact of the incident"""
        services_affected = set(event.service for event in events)
        error_events = [e for e in events if e.level == "ERROR"]
        warning_events = [e for e in events if e.level == "WARNING"]
        
        # Calculate incident duration
        if len(events) > 1:
            start_time = min(event.timestamp for event in events)
            end_time = max(event.timestamp for event in events)
            duration = (end_time - start_time).total_seconds()
        else:
            duration = 0
        
        return {
            "services_affected": list(services_affected),
            "total_services": len(services_affected),
            "error_count": len(error_events),
            "warning_count": len(warning_events),
            "duration_seconds": duration,
            "severity": "HIGH" if len(error_events) > 2 else "MEDIUM" if len(error_events) > 0 else "LOW"
        }
    
    def _summarize_graph(self, causal_graph) -> Dict[str, Any]:
        """Create a summary of the causal graph"""
        import networkx as nx
        # Convert to undirected graph to find connected components
        undirected_graph = causal_graph.to_undirected()
        return {
            "nodes": causal_graph.number_of_nodes(),
            "edges": causal_graph.number_of_edges(),
            "connected_components": len(list(nx.connected_components(undirected_graph)))
        }
    
    def get_causal_graph(self, incident_id: str) -> Optional[Dict[str, Any]]:
        """Get causal graph data for visualization"""
        if incident_id not in self.active_incidents:
            return None
        
        incident = self.active_incidents[incident_id]
        
        # Build graph for visualization
        causal_graph = self.causal_graph_builder.build_graph(
            incident.events, self.service_dependencies
        )
        
        # Convert to JSON-serializable format
        nodes = []
        edges = []
        
        for event in incident.events:
            nodes.append({
                "id": event.id,
                "label": f"{event.service}\n{event.level}",
                "service": event.service,
                "level": event.level,
                "timestamp": event.timestamp.isoformat(),
                "message": event.message[:50] + "..." if len(event.message) > 50 else event.message
            })
        
        for event1 in incident.events:
            for event2 in incident.events:
                if (event1.id != event2.id and 
                    self._events_are_related(event1, event2) and
                    event1.timestamp < event2.timestamp):
                    edges.append({
                        "from": event1.id,
                        "to": event2.id,
                        "weight": 0.8  # Simplified weight
                    })
        
        return {
            "incident_id": incident_id,
            "nodes": nodes,
            "edges": edges,
            "metadata": {
                "total_events": len(incident.events),
                "root_causes": len(incident.root_causes),
                "top_root_cause": incident.root_causes[0].description if incident.root_causes else None
            }
        }
