import re
from datetime import datetime
from .base import BaseHandler
from ..models.log_entry import LogEntry

class TextHandler(BaseHandler):
    # Common log patterns
    PATTERNS = [
        # Apache/Nginx style: [timestamp] level: message
        r'^\[([^\]]+)\]\s+(\w+):\s+(.+)$',
        # Syslog style: timestamp host service[pid]: message
        r'^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\w+)\s+([^:]+):\s*(.+)$',
        # Simple: timestamp level message
        r'^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(\w+)\s+(.+)$'
    ]
    
    def can_handle(self, raw_data: bytes) -> float:
        """Check if data looks like structured text log"""
        try:
            text = raw_data.decode('utf-8').strip()
            for pattern in self.PATTERNS:
                if re.match(pattern, text):
                    return 0.8
            return 0.3  # Fallback for any text
        except UnicodeDecodeError:
            return 0.0
    
    def parse(self, raw_data: bytes) -> LogEntry:
        """Parse text log using pattern matching"""
        text = raw_data.decode('utf-8').strip()
        
        for pattern in self.PATTERNS:
            match = re.match(pattern, text)
            if match:
                groups = match.groups()
                if len(groups) >= 3:
                    timestamp = self._parse_timestamp(groups[0])
                    level = groups[1].upper()
                    message = groups[2] if len(groups) == 3 else groups[3]
                    source = groups[2] if len(groups) == 4 else 'unknown'
                    
                    return LogEntry(
                        timestamp=timestamp,
                        level=level,
                        message=message,
                        source=source
                    )
        
        # Fallback for unstructured text
        return LogEntry(
            timestamp=datetime.now(),
            level='INFO',
            message=text,
            source='text-parser'
        )
    
    def _parse_timestamp(self, timestamp_str: str) -> datetime:
        """Parse common timestamp formats"""
        patterns = [
            '%Y-%m-%d %H:%M:%S',
            '%Y-%m-%dT%H:%M:%S',
            '%b %d %H:%M:%S'
        ]
        
        for pattern in patterns:
            try:
                return datetime.strptime(timestamp_str, pattern)
            except ValueError:
                continue
        
        return datetime.now()  # Fallback
