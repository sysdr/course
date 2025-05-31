"""
Syslog Adapter - RFC 3164 and RFC 5424 Compatible
Parses traditional Unix syslog format into unified schema
"""

import re
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List
from config.compatibility_config import config

class SyslogAdapter:
    """Adapter for parsing syslog format logs"""
    
    def __init__(self):
        self.config = config.adapters['syslog']
        self.facilities = self.config['facilities']
        self.severities = self.config['severities']
        
        # Compiled regex patterns for performance
        self.rfc3164_pattern = re.compile(
            r'^<(\d{1,3})>(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+(.+)$'
        )
        
        self.rfc5424_pattern = re.compile(
            r'^<(\d{1,3})>(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$'
        )
    
    def parse(self, log_line: str) -> Dict[str, Any]:
        """
        Parse a syslog format log line into structured data
        
        Args:
            log_line: Raw syslog line
            
        Returns:
            Parsed log data or None if parsing fails
        """
        log_line = log_line.strip()
        
        if not log_line:
            return None
            
        # Try RFC 5424 format first (newer)
        rfc5424_match = self.rfc5424_pattern.match(log_line)
        if rfc5424_match:
            return self._parse_rfc5424(rfc5424_match)
        
        # Fall back to RFC 3164 format
        rfc3164_match = self.rfc3164_pattern.match(log_line)
        if rfc3164_match:
            return self._parse_rfc3164(rfc3164_match)
        
        # If no pattern matches, treat as legacy format
        return self._parse_legacy(log_line)
    
    def _parse_rfc5424(self, match) -> Dict[str, Any]:
        """Parse RFC 5424 syslog format"""
        priority, version, timestamp, hostname, app_name, proc_id, msg_id, message = match.groups()
        
        facility, severity = self._decode_priority(int(priority))
        
        # Parse timestamp
        try:
            if timestamp != '-':
                parsed_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            else:
                parsed_time = datetime.now(timezone.utc)
        except ValueError:
            parsed_time = datetime.now(timezone.utc)
        
        return {
            'timestamp': parsed_time.isoformat(),
            'level': self.severities.get(severity, 'INFO'),
            'facility': self.facilities.get(facility, 'unknown'),
            'hostname': hostname if hostname != '-' else None,
            'app_name': app_name if app_name != '-' else None,
            'process_id': proc_id if proc_id != '-' else None,
            'message_id': msg_id if msg_id != '-' else None,
            'message': message,
            'source_format': 'syslog_rfc5424',
            'priority': int(priority)
        }
    
    def _parse_rfc3164(self, match) -> Dict[str, Any]:
        """Parse RFC 3164 syslog format"""
        priority, timestamp, hostname, message = match.groups()
        
        facility, severity = self._decode_priority(int(priority))
        
        # Parse timestamp (no year in RFC 3164)
        try:
            current_year = datetime.now().year
            timestamp_with_year = f"{current_year} {timestamp}"
            parsed_time = datetime.strptime(timestamp_with_year, "%Y %b %d %H:%M:%S")
            parsed_time = parsed_time.replace(tzinfo=timezone.utc)
        except ValueError:
            parsed_time = datetime.now(timezone.utc)
        
        return {
            'timestamp': parsed_time.isoformat(),
            'level': self.severities.get(severity, 'INFO'),
            'facility': self.facilities.get(facility, 'unknown'),
            'hostname': hostname,
            'message': message,
            'source_format': 'syslog_rfc3164',
            'priority': int(priority)
        }
    
    def _parse_legacy(self, log_line: str) -> Dict[str, Any]:
        """Handle non-standard syslog formats"""
        # Extract priority if present
        priority_match = re.match(r'^<(\d{1,3})>', log_line)
        if priority_match:
            priority = int(priority_match.group(1))
            facility, severity = self._decode_priority(priority)
            message = log_line[priority_match.end():].strip()
        else:
            facility, severity = 1, 6  # Default to user.info
            priority = facility * 8 + severity
            message = log_line
        
        return {
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'level': self.severities.get(severity, 'INFO'),
            'facility': self.facilities.get(facility, 'user'),
            'message': message,
            'source_format': 'syslog_legacy',
            'priority': priority
        }
    
    def _decode_priority(self, priority: int) -> tuple:
        """Decode syslog priority into facility and severity"""
        facility = priority // 8
        severity = priority % 8
        return facility, severity
    
    def batch_parse(self, log_lines: List[str]) -> List[Dict[str, Any]]:
        """Parse multiple syslog lines efficiently"""
        results = []
        
        for line in log_lines:
            parsed = self.parse(line)
            if parsed:
                results.append(parsed)
        
        return results
