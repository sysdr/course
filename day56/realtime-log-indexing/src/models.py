from datetime import datetime
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, asdict
import json
import hashlib

@dataclass
class LogEntry:
    timestamp: datetime
    level: str
    service: str
    message: str
    metadata: Dict[str, Any]
    id: Optional[str] = None
    
    def __post_init__(self):
        if not self.id:
            content = f"{self.timestamp}{self.service}{self.message}"
            self.id = hashlib.md5(content.encode()).hexdigest()[:12]
    
    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        data['timestamp'] = self.timestamp.isoformat()
        return data
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'LogEntry':
        if isinstance(data['timestamp'], str):
            data['timestamp'] = datetime.fromisoformat(data['timestamp'])
        return cls(**data)
    
    def extract_searchable_terms(self) -> List[str]:
        """Extract terms for indexing"""
        terms = []
        
        # Index service and level
        terms.extend([self.service.lower(), self.level.lower()])
        
        # Index message words
        message_words = self.message.lower().split()
        terms.extend([word.strip('.,!?;:') for word in message_words])
        
        # Index metadata values
        for key, value in self.metadata.items():
            if isinstance(value, str):
                terms.append(f"{key}:{value.lower()}")
            else:
                terms.append(f"{key}:{str(value)}")
        
        return [term for term in terms if len(term) > 1]

@dataclass
class IndexSegment:
    segment_id: str
    creation_time: datetime
    document_count: int
    memory_size: int
    is_persistent: bool
    index_path: Optional[str] = None
    
@dataclass
class SearchQuery:
    terms: List[str]
    filters: Dict[str, str]
    limit: int = 100
    include_recent: bool = True
    
@dataclass
class SearchResult:
    log_entry: LogEntry
    score: float
    segment_id: str
