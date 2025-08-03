"""
Confidence Scorer
Calculates confidence scores for root cause hypotheses
"""

import networkx as nx
from typing import List
from models.log_event import LogEvent, RootCause

class ConfidenceScorer:
    def calculate_confidence(self, root_cause: RootCause, events: List[LogEvent], 
                           causal_graph: nx.DiGraph) -> float:
        """Calculate confidence score for a root cause hypothesis"""
        score = 0.0
        
        # Base score for error level events
        event = next((e for e in events if e.id == root_cause.event_id), None)
        if not event:
            return 0.0
        
        if event.level == "ERROR":
            score += 0.4
        elif event.level == "CRITICAL":
            score += 0.6
        elif event.level == "WARNING":
            score += 0.2
        
        # Temporal positioning score (earlier events more likely to be root causes)
        earliest_time = min(e.timestamp for e in events)
        latest_time = max(e.timestamp for e in events)
        
        if earliest_time != latest_time:
            time_position = (event.timestamp - earliest_time) / (latest_time - earliest_time)
            temporal_score = max(0, 0.3 - (time_position * 0.3))  # Earlier = higher score
            score += temporal_score
        else:
            score += 0.15  # Single event gets moderate temporal score
        
        # Graph centrality score
        try:
            if root_cause.event_id in causal_graph:
                out_degree = causal_graph.out_degree(root_cause.event_id)
                max_out_degree = max([causal_graph.out_degree(n) for n in causal_graph.nodes()], default=1)
                centrality_score = (out_degree / max_out_degree) * 0.2
                score += centrality_score
        except:
            pass
        
        # Impact scope score
        impact_score = min(0.2, len(root_cause.affected_services) * 0.05)
        score += impact_score
        
        # Service criticality score (simplified)
        critical_services = ["database", "auth-service", "api-gateway"]
        if root_cause.service in critical_services:
            score += 0.1
        
        return min(1.0, score)
