"""
Journald Adapter - systemd Journal Format
Parses journald binary journal entries and key=value text format
"""

import json
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List
from config.compatibility_config import config

class JournaldAdapter:
    """Adapter for parsing journald format logs"""
    
    def __init__(self):
        self.config = config.adapters['journald']
        self.required_fields = self.config['required_fields']
        self.optional_fields = self.config['optional_fields']
        
        # Priority level mapping from journald to unified schema
        self.priority_mapping = {
            '0': 'CRITICAL',  # Emergency
            '1': 'CRITICAL',  # Alert  
            '2': 'CRITICAL',  # Critical
            '3': 'ERROR',     # Error
            '4': 'WARNING',   # Warning
            '5': 'INFO',      # Notice
            '6': 'INFO',      # Info
            '7': 'DEBUG'      # Debug
        }
    
    def parse(self, log_line: str) -> Dict[str, Any]:
        """
        Parse a journald format log line into structured data
        
        Args:
            log_line: Raw journald line (key=value format)
            
        Returns:
            Parsed log data or None if parsing fails
        """
        log_line = log_line.strip()
        
        if not log_line:
            return None
        
        # Try to parse as JSON first (some journald exports use JSON)
        try:
            data = json.loads(log_line)
            if isinstance(data, dict):
                return self._parse_json_format(data)
        except (json.JSONDecodeError, TypeError):
            pass
        
        # Parse key=value format
        return self._parse_keyvalue_format(log_line)
    
    def _parse_json_format(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Parse JSON-formatted journald entry"""
        # Extract timestamp
        timestamp = self._extract_timestamp(data)
        
        # Extract message
        message = data.get('MESSAGE', data.get('message', ''))
        
        # Extract priority/level
        priority = data.get('PRIORITY', data.get('priority', '6'))
        level = self.priority_mapping.get(str(priority), 'INFO')
        
        # Extract process information
        process_id = data.get('_PID', data.get('pid'))
        user_id = data.get('_UID', data.get('uid'))
        command = data.get('_COMM', data.get('command'))
        
        return {
            'timestamp': timestamp,
            'level': level,
            'message': message,
            'source_format': 'journald_json',
            'process_id': str(process_id) if process_id else None,
            'user_id': str(user_id) if user_id else None,
            'command': command,
            'priority': str(priority),
            'raw_fields': {k: v for k, v in data.items() if k.startswith('_')}
        }
    
    def _parse_keyvalue_format(self, log_line: str) -> Dict[str, Any]:
        """Parse key=value format journald entry"""
        fields = {}
        
        # Simple key=value parser
        # Note: This is simplified - real journald can have complex escaping
        for part in log_line.split('\n'):
            if '=' in part:
                key, value = part.split('=', 1)
                fields[key.strip()] = value.strip()
        
        # Validate required fields
        if not any(field in fields for field in self.required_fields):
            return None
        
        # Extract timestamp
        timestamp = self._extract_timestamp(fields)
        
        # Extract message
        message = fields.get('MESSAGE', '')
        
        # Extract priority/level  
        priority = fields.get('PRIORITY', '6')
        level = self.priority_mapping.get(str(priority), 'INFO')
        
        # Extract process information
        process_id = fields.get('_PID')
        user_id = fields.get('_UID')
        command = fields.get('_COMM')
        hostname = fields.get('_HOSTNAME')
        
        return {
            'timestamp': timestamp,
            'level': level,
            'message': message,
            'source_format': 'journald_keyvalue',
            'process_id': process_id,
            'user_id': user_id,
            'command': command,
            'hostname': hostname,
            'priority': priority,
            'raw_fields': {k: v for k, v in fields.items() if k.startswith('_')}
        }
    
    def _extract_timestamp(self, data: Dict[str, Any]) -> str:
        """Extract and normalize timestamp from journald data"""
        # Try __REALTIME_TIMESTAMP first (microseconds since epoch)
        realtime = data.get('__REALTIME_TIMESTAMP')
        if realtime:
            try:
                # Convert microseconds to seconds
                timestamp_seconds = int(realtime) / 1000000
                dt = datetime.fromtimestamp(timestamp_seconds, tz=timezone.utc)
                return dt.isoformat()
            except (ValueError, TypeError):
                pass
        
        # Try other timestamp fields
        for field in ['timestamp', 'TIMESTAMP', '_SOURCE_REALTIME_TIMESTAMP']:
            if field in data:
                try:
                    timestamp = data[field]
                    if isinstance(timestamp, str):
                        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                        return dt.isoformat()
                except (ValueError, TypeError):
                    continue
        
        # Default to current time
        return datetime.now(timezone.utc).isoformat()
    
    def batch_parse(self, log_lines: List[str]) -> List[Dict[str, Any]]:
        """Parse multiple journald lines efficiently"""
        results = []
        
        for line in log_lines:
            parsed = self.parse(line)
            if parsed:
                results.append(parsed)
        
        return results
    
    def parse_journal_export(self, export_data: str) -> List[Dict[str, Any]]:
        """
        Parse journald export format (multi-line entries separated by empty lines)
        
        Args:
            export_data: Raw journald export output
            
        Returns:
            List of parsed log entries
        """
        results = []
        current_entry = []
        
        for line in export_data.split('\n'):
            if line.strip() == '' and current_entry:
                # End of entry, parse it
                entry_text = '\n'.join(current_entry)
                parsed = self.parse(entry_text)
                if parsed:
                    results.append(parsed)
                current_entry = []
            elif line.strip():
                current_entry.append(line)
        
        # Handle last entry if no trailing empty line
        if current_entry:
            entry_text = '\n'.join(current_entry)
            parsed = self.parse(entry_text)
            if parsed:
                results.append(parsed)
        
        return results
