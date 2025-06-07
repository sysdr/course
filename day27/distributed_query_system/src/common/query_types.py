from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional, Union
from datetime import datetime
import uuid

@dataclass
class TimeRange:
    start: datetime
    end: datetime
    
    def overlaps(self, other: 'TimeRange') -> bool:
        return self.start <= other.end and self.end >= other.start
    
    def duration_seconds(self) -> float:
        return (self.end - self.start).total_seconds()

@dataclass
class QueryFilter:
    field: str
    operator: str  # eq, ne, contains, regex, gt, lt
    value: Any
    
    def matches(self, log_entry: Dict[str, Any]) -> bool:
        if self.field not in log_entry:
            return False
            
        entry_value = log_entry[self.field]
        
        if self.operator == "eq":
            return entry_value == self.value
        elif self.operator == "ne":
            return entry_value != self.value
        elif self.operator == "contains":
            return str(self.value).lower() in str(entry_value).lower()
        elif self.operator == "gt":
            return entry_value > self.value
        elif self.operator == "lt":
            return entry_value < self.value
        
        return False

@dataclass
class Query:
    query_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    time_range: Optional[TimeRange] = None
    filters: List[QueryFilter] = field(default_factory=list)
    sort_field: str = "timestamp"
    sort_order: str = "desc"  # asc or desc
    limit: Optional[int] = None
    include_fields: List[str] = field(default_factory=list)
    exclude_fields: List[str] = field(default_factory=list)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "query_id": self.query_id,
            "time_range": {
                "start": self.time_range.start.isoformat() if self.time_range else None,
                "end": self.time_range.end.isoformat() if self.time_range else None
            },
            "filters": [
                {"field": f.field, "operator": f.operator, "value": f.value}
                for f in self.filters
            ],
            "sort_field": self.sort_field,
            "sort_order": self.sort_order,
            "limit": self.limit
        }

@dataclass
class QueryResult:
    query_id: str
    partition_id: str
    results: List[Dict[str, Any]]
    total_matches: int
    execution_time_ms: float
    errors: List[str] = field(default_factory=list)
    
    def is_successful(self) -> bool:
        return len(self.errors) == 0
        
    def to_dict(self) -> Dict[str, Any]:
        return {
            "query_id": self.query_id,
            "partition_id": self.partition_id,
            "results": self.results,
            "total_matches": self.total_matches,
            "execution_time_ms": self.execution_time_ms,
            "errors": self.errors
        }

@dataclass
class MergedQueryResult:
    query_id: str
    total_results: int
    results: List[Dict[str, Any]]
    partitions_queried: int
    partitions_successful: int
    total_execution_time_ms: float
    errors: List[str] = field(default_factory=list)
    
    def success_rate(self) -> float:
        if self.partitions_queried == 0:
            return 0.0
        return self.partitions_successful / self.partitions_queried
