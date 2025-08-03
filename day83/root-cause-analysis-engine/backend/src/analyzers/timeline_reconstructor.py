"""
Timeline Reconstructor
Builds accurate chronological sequences of related events
"""

from typing import List, Dict, Any
from datetime import datetime

from models.log_event import LogEvent

class TimelineReconstructor:
    def reconstruct(self, events: List[LogEvent]) -> List[Dict[str, Any]]:
        """Reconstruct chronological timeline from events"""
        # Sort events by timestamp
        sorted_events = sorted(events, key=lambda x: x.timestamp)
        
        timeline = []
        for i, event in enumerate(sorted_events):
            timeline_entry = {
                "sequence_id": i + 1,
                "timestamp": event.timestamp.isoformat(),
                "relative_time": self._calculate_relative_time(event, sorted_events[0]),
                "service": event.service,
                "level": event.level,
                "message": event.message,
                "event_id": event.id,
                "context": self._build_context(event, sorted_events, i)
            }
            timeline.append(timeline_entry)
        
        return timeline
    
    def _calculate_relative_time(self, event: LogEvent, start_event: LogEvent) -> str:
        """Calculate relative time from incident start"""
        if event.timestamp == start_event.timestamp:
            return "T+0:00"
        
        diff = event.timestamp - start_event.timestamp
        total_seconds = int(diff.total_seconds())
        minutes, seconds = divmod(total_seconds, 60)
        return f"T+{minutes}:{seconds:02d}"
    
    def _build_context(self, event: LogEvent, all_events: List[LogEvent], index: int) -> Dict[str, Any]:
        """Build contextual information for the event"""
        context = {
            "is_first": index == 0,
            "is_last": index == len(all_events) - 1,
            "preceding_events": index,
            "following_events": len(all_events) - index - 1
        }
        
        # Find related events in the same service
        service_events = [e for e in all_events if e.service == event.service]
        context["service_event_count"] = len(service_events)
        context["service_event_position"] = [e.id for e in service_events].index(event.id) + 1
        
        return context
