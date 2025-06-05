"""
Unified Output Formatter
Converts validated log entries to consistent output format
"""

import json
from datetime import datetime
from typing import Dict, Any, List, Optional
from config.compatibility_config import config

class UnifiedFormatter:
    """Formats validated log entries into unified output format"""
    
    def __init__(self):
        self.schema = config.unified_schema
        self.output_format = 'json'  # Default format
        
    def format_entry(self, log_entry: Dict[str, Any], output_format: str = 'json') -> str:
        """
        Format a single log entry for output
        
        Args:
            log_entry: Validated log entry
            output_format: Output format ('json', 'structured', 'simple')
            
        Returns:
            Formatted log string
        """
        if output_format == 'json':
            return self._format_json(log_entry)
        elif output_format == 'structured':
            return self._format_structured(log_entry)
        elif output_format == 'simple':
            return self._format_simple(log_entry)
        else:
            raise ValueError(f"Unsupported output format: {output_format}")
    
    def _format_json(self, log_entry: Dict[str, Any]) -> str:
        """Format as JSON line"""
        # Ensure consistent field ordering
        ordered_entry = {}
        
        # Add required fields first
        for field in self.schema['required_fields']:
            if field in log_entry:
                ordered_entry[field] = log_entry[field]
        
        # Add optional fields
        for field in self.schema['optional_fields']:
            if field in log_entry and log_entry[field] is not None:
                ordered_entry[field] = log_entry[field]
        
        # Add any additional fields
        for key, value in log_entry.items():
            if key not in ordered_entry:
                ordered_entry[key] = value
        
        return json.dumps(ordered_entry, separators=(',', ':'))
    
    def _format_structured(self, log_entry: Dict[str, Any]) -> str:
        """Format as structured text"""
        timestamp = log_entry.get('timestamp', 'UNKNOWN')
        level = log_entry.get('level', 'INFO')
        message = log_entry.get('message', '')
        source = log_entry.get('source_format', 'unknown')
        
        # Basic structured format
        result = f"[{timestamp}] {level}: {message}"
        
        # Add optional context
        context_parts = []
        if log_entry.get('hostname'):
            context_parts.append(f"host={log_entry['hostname']}")
        if log_entry.get('facility'):
            context_parts.append(f"facility={log_entry['facility']}")
        if log_entry.get('process_id'):
            context_parts.append(f"pid={log_entry['process_id']}")
        
        if context_parts:
            result += f" ({', '.join(context_parts)})"
        
        result += f" [source: {source}]"
        
        return result
    
    def _format_simple(self, log_entry: Dict[str, Any]) -> str:
        """Format as simple text"""
        timestamp = log_entry.get('timestamp', 'UNKNOWN')
        level = log_entry.get('level', 'INFO')
        message = log_entry.get('message', '')
        
        # Parse timestamp for readable format
        try:
            dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            readable_time = dt.strftime('%Y-%m-%d %H:%M:%S')
        except:
            readable_time = timestamp
        
        return f"{readable_time} [{level}] {message}"
    
    def batch_format(self, log_entries: List[Dict[str, Any]], 
                    output_format: str = 'json') -> List[str]:
        """
        Format multiple log entries
        
        Args:
            log_entries: List of validated log entries
            output_format: Output format for all entries
            
        Returns:
            List of formatted log strings
        """
        return [self.format_entry(entry, output_format) for entry in log_entries]
    
    def format_to_file(self, log_entries: List[Dict[str, Any]], 
                      filepath: str, output_format: str = 'json') -> Dict[str, Any]:
        """
        Format and write log entries to file
        
        Args:
            log_entries: List of validated log entries
            filepath: Output file path
            output_format: Output format
            
        Returns:
            Summary of formatting operation
        """
        try:
            formatted_entries = self.batch_format(log_entries, output_format)
            
            with open(filepath, 'w') as f:
                for entry in formatted_entries:
                    f.write(entry + '\n')
            
            return {
                'success': True,
                'entries_written': len(formatted_entries),
                'filepath': filepath,
                'format': output_format
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'entries_written': 0
            }
    
    def create_summary(self, processing_results: Dict[str, Any]) -> Dict[str, Any]:
        """Create processing summary for monitoring and debugging"""
        summary = {
            'processing_timestamp': datetime.now().isoformat(),
            'total_input_logs': processing_results.get('total_input', 0),
            'format_detection': processing_results.get('detection_summary', {}),
            'parsing_results': {
                'syslog_parsed': processing_results.get('syslog_count', 0),
                'journald_parsed': processing_results.get('journald_count', 0),
                'json_parsed': processing_results.get('json_count', 0),
                'failed_to_parse': processing_results.get('parse_failures', 0)
            },
            'validation_results': processing_results.get('validation_summary', {}),
            'output_results': {
                'total_output_logs': processing_results.get('output_count', 0),
                'output_format': processing_results.get('output_format', 'json'),
                'success_rate': processing_results.get('success_rate', 0.0)
            },
            'performance_metrics': {
                'processing_time_seconds': processing_results.get('processing_time', 0),
                'logs_per_second': processing_results.get('throughput', 0),
                'memory_usage_mb': processing_results.get('memory_usage', 0)
            }
        }
        
        return summary
