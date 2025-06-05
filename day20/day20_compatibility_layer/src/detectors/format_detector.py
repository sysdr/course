"""
Format Detection Engine
Automatically identifies log format types from input streams
"""

import re
import json
from typing import Optional, Dict, Any
from datetime import datetime

class FormatDetector:
    """Detects log format types using pattern matching and heuristics"""
    
    def __init__(self):
        # Syslog patterns - RFC 3164 and RFC 5424
        self.syslog_patterns = [
            r'^<\d{1,3}>', # Priority field at start
            r'^\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}', # Timestamp pattern
            r'^<\d{1,3}>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' # RFC 5424
        ]
        
        # Journald patterns
        self.journald_patterns = [
            r'__REALTIME_TIMESTAMP=\d+',
            r'MESSAGE=.*',
            r'_PID=\d+',
            r'PRIORITY=\d+'
        ]
        
        # JSON patterns
        self.json_patterns = [
            r'^\s*{.*}\s*$',
            r'"timestamp".*:.*"',
            r'"level".*:.*"'
        ]
    
    def detect_format(self, log_line: str) -> Dict[str, Any]:
        """
        Detect the format of a single log line
        
        Args:
            log_line: Raw log line to analyze
            
        Returns:
            Dictionary with format type and confidence score
        """
        log_line = log_line.strip()
        
        if not log_line:
            return {'format': 'empty', 'confidence': 0.0, 'details': {}}
        
        # Test for syslog format
        syslog_score = self._test_syslog(log_line)
        
        # Test for journald format  
        journald_score = self._test_journald(log_line)
        
        # Test for JSON format
        json_score = self._test_json(log_line)
        
        # Determine best match
        scores = {
            'syslog': syslog_score,
            'journald': journald_score, 
            'json': json_score
        }
        
        best_format = max(scores, key=scores.get)
        confidence = scores[best_format]
        
        return {
            'format': best_format if confidence > 0.5 else 'unknown',
            'confidence': confidence,
            'details': {
                'scores': scores,
                'sample': log_line[:100] + '...' if len(log_line) > 100 else log_line
            }
        }
    
    def _test_syslog(self, log_line: str) -> float:
        """Test if log line matches syslog format"""
        score = 0.0
        
        # Check for priority field
        if re.match(r'^<\d{1,3}>', log_line):
            score += 0.4
            
        # Check for timestamp patterns
        for pattern in self.syslog_patterns[1:]:
            if re.search(pattern, log_line):
                score += 0.3
                break
        
        # Check for typical syslog structure
        if ' ' in log_line and len(log_line.split()) >= 3:
            score += 0.2
            
        return min(score, 1.0)
    
    def _test_journald(self, log_line: str) -> float:
        """Test if log line matches journald format"""
        score = 0.0
        
        # Check for journald field patterns
        for pattern in self.journald_patterns:
            if re.search(pattern, log_line):
                score += 0.25
        
        # Check for key=value structure
        if '=' in log_line and not log_line.startswith('<'):
            score += 0.2
            
        return min(score, 1.0)
    
    def _test_json(self, log_line: str) -> float:
        """Test if log line is valid JSON"""
        score = 0.0
        
        try:
            data = json.loads(log_line)
            if isinstance(data, dict):
                score += 0.5
                
                # Check for common log fields
                common_fields = ['timestamp', 'level', 'message', 'time']
                for field in common_fields:
                    if field in data:
                        score += 0.1
                        
        except (json.JSONDecodeError, TypeError):
            pass
            
        return min(score, 1.0)

    def batch_detect(self, log_lines: list) -> Dict[str, Any]:
        """
        Detect format for multiple log lines and provide aggregate analysis
        
        Args:
            log_lines: List of log lines to analyze
            
        Returns:
            Summary of format detection across all lines
        """
        results = []
        format_counts = {}
        
        for line in log_lines:
            detection = self.detect_format(line)
            results.append(detection)
            
            fmt = detection['format']
            format_counts[fmt] = format_counts.get(fmt, 0) + 1
        
        # Determine dominant format
        total_lines = len(log_lines)
        dominant_format = max(format_counts, key=format_counts.get) if format_counts else 'unknown'
        
        return {
            'total_lines': total_lines,
            'dominant_format': dominant_format,
            'format_distribution': format_counts,
            'confidence_avg': sum(r['confidence'] for r in results) / total_lines if total_lines > 0 else 0,
            'individual_results': results
        }
