import re
from datetime import datetime
from typing import Optional, Dict, Any
import pytz
from dateutil import parser
import structlog
import json

logger = structlog.get_logger()

class TimeExtractor:
    def __init__(self, default_timezone: str = "UTC"):
        self.default_tz = pytz.timezone(default_timezone)
        self.common_patterns = [
            # ISO format
            r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?',
            # Apache log format
            r'\[\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2} [+-]\d{4}\]',
            # Syslog format
            r'\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}',
            # Epoch timestamps
            r'\b\d{10}\b|\b\d{13}\b'
        ]
        
    def extract_timestamp(self, log_entry: str, metadata: Optional[Dict] = None) -> Optional[int]:
        """Extract timestamp from log entry and convert to epoch seconds"""
        try:
            # Check metadata first
            if metadata and 'timestamp' in metadata:
                return self._parse_timestamp(metadata['timestamp'])
                
            # Try to parse structured log (JSON)
            if log_entry.strip().startswith('{'):
                try:
                    log_data = json.loads(log_entry)
                    for field in ['timestamp', 'time', '@timestamp', 'datetime']:
                        if field in log_data:
                            return self._parse_timestamp(log_data[field])
                except json.JSONDecodeError:
                    pass
                    
            # Extract from raw log text using patterns
            for pattern in self.common_patterns:
                matches = re.findall(pattern, log_entry)
                if matches:
                    return self._parse_timestamp(matches[0])
                    
            # Default to current time if no timestamp found
            logger.warning("No timestamp found in log entry, using current time")
            return int(datetime.now(self.default_tz).timestamp())
            
        except Exception as e:
            logger.error("Error extracting timestamp", error=str(e), log_entry=log_entry[:100])
            return int(datetime.now(self.default_tz).timestamp())
            
    def _parse_timestamp(self, timestamp_str: Any) -> int:
        """Parse timestamp string to epoch seconds"""
        if isinstance(timestamp_str, (int, float)):
            # Handle epoch timestamps
            if timestamp_str > 1e12:  # Milliseconds
                return int(timestamp_str / 1000)
            return int(timestamp_str)
            
        if isinstance(timestamp_str, str):
            # Clean up common formats
            timestamp_str = timestamp_str.strip('[]')
            
            # Try parsing with dateutil
            try:
                dt = parser.parse(timestamp_str)
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=self.default_tz)
                return int(dt.timestamp())
            except Exception:
                pass
                
            # Try epoch timestamp
            try:
                timestamp_num = float(timestamp_str)
                if timestamp_num > 1e12:  # Milliseconds
                    return int(timestamp_num / 1000)
                return int(timestamp_num)
            except ValueError:
                pass
                
        # Fallback to current time
        return int(datetime.now(self.default_tz).timestamp())
        
    def normalize_log_entry(self, log_entry: str, metadata: Optional[Dict] = None) -> Dict[str, Any]:
        """Normalize log entry with extracted timestamp"""
        timestamp = self.extract_timestamp(log_entry, metadata)
        
        # Try to parse as JSON first
        try:
            if log_entry.strip().startswith('{'):
                data = json.loads(log_entry)
                data['extracted_timestamp'] = timestamp
                # Ensure service field is preserved
                if 'service' not in data:
                    data['service'] = self._extract_service(log_entry)
                return data
        except:
            pass
            
        # Create structured entry for unstructured logs
        return {
            'raw_message': log_entry,
            'extracted_timestamp': timestamp,
            'level': self._extract_level(log_entry),
            'service': self._extract_service(log_entry),
            'normalized_at': int(datetime.now().timestamp())
        }
        
    def _extract_level(self, log_entry: str) -> str:
        """Extract log level from entry"""
        levels = ['ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE']
        log_upper = log_entry.upper()
        
        for level in levels:
            if level in log_upper:
                return level
        return 'INFO'
        
    def _extract_service(self, log_entry: str) -> str:
        """Extract service name from log entry"""
        # Look for common service patterns
        patterns = [
            r'service[_-]name[:\s]*([a-zA-Z0-9_-]+)',
            r'application[:\s]*([a-zA-Z0-9_-]+)',
            r'\[([a-zA-Z0-9_-]+)\]'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, log_entry, re.IGNORECASE)
            if match:
                return match.group(1)
                
        return 'unknown'
