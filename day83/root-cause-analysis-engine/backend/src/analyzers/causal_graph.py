"""
Causal Graph Builder
Constructs directed graphs showing causal relationships between events
"""

import networkx as nx
from typing import List, Dict, Any
from datetime import timedelta

from models.log_event import LogEvent

class CausalGraphBuilder:
    def __init__(self):
        self.temporal_window = timedelta(minutes=5)  # Events within 5 minutes can be causal
    
    def build_graph(self, events: List[LogEvent], service_dependencies: Dict[str, List[str]]) -> nx.DiGraph:
        """Build a directed causal graph from log events"""
        graph = nx.DiGraph()
        
        # Add nodes for each event
        for event in events:
            graph.add_node(event.id, **{
                "timestamp": event.timestamp,
                "service": event.service,
                "level": event.level,
                "message": event.message
            })
        
        # Add edges for causal relationships
        for i, event1 in enumerate(events):
            for j, event2 in enumerate(events):
                if i != j and self._is_causal_relationship(event1, event2, service_dependencies):
                    # Calculate edge weight based on causal strength
                    weight = self._calculate_causal_strength(event1, event2, service_dependencies)
                    graph.add_edge(event1.id, event2.id, weight=weight)
        
        return graph
    
    def _is_causal_relationship(self, event1: LogEvent, event2: LogEvent, 
                               service_dependencies: Dict[str, List[str]]) -> bool:
        """Determine if event1 could have caused event2"""
        # Temporal constraint: event1 must occur before event2
        if event1.timestamp >= event2.timestamp:
            return False
        
        # Time window constraint
        time_diff = event2.timestamp - event1.timestamp
        if time_diff > self.temporal_window:
            return False
        
        # Service dependency constraint
        if event1.service in service_dependencies:
            if event2.service in service_dependencies[event1.service]:
                return True
        
        # Error propagation pattern
        if event1.level == "ERROR" and event2.level in ["ERROR", "WARNING"]:
            return True
        
        # Same service sequential events
        if event1.service == event2.service:
            return True
        
        return False
    
    def _calculate_causal_strength(self, event1: LogEvent, event2: LogEvent,
                                  service_dependencies: Dict[str, List[str]]) -> float:
        """Calculate the strength of causal relationship between two events"""
        strength = 0.5  # Base strength
        
        # Increase strength for direct service dependencies
        if (event1.service in service_dependencies and 
            event2.service in service_dependencies[event1.service]):
            strength += 0.3
        
        # Increase strength for error propagation
        if event1.level == "ERROR" and event2.level == "ERROR":
            strength += 0.2
        
        # Decrease strength based on time gap
        time_gap = (event2.timestamp - event1.timestamp).total_seconds()
        if time_gap > 60:  # More than 1 minute
            strength -= 0.1
        
        return min(1.0, max(0.1, strength))
