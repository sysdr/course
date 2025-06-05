from abc import ABC, abstractmethod
from typing import Dict, Any
from ..models.log_entry import LogEntry

class BaseHandler(ABC):
    @abstractmethod
    def can_handle(self, raw_data: bytes) -> float:
        """Return confidence score (0-1) for handling this data format"""
        pass
    
    @abstractmethod
    def parse(self, raw_data: bytes) -> LogEntry:
        """Parse raw data into standardized LogEntry"""
        pass
