import re
import json
from typing import Iterator, Tuple, List, Any
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

def word_count_mapper(log_line: str) -> Iterator[Tuple[str, int]]:
    """Map function for word count analysis"""
    try:
        # Parse log line - assume it's JSON or space-separated
        if log_line.strip().startswith('{'):
            # JSON log format
            log_data = json.loads(log_line)
            text = log_data.get('message', '') + ' ' + log_data.get('error', '')
        else:
            # Plain text log format
            text = log_line
        
        # Extract words (alphanumeric only)
        words = re.findall(r'\b[a-zA-Z]+\b', text.lower())
        
        for word in words:
            if len(word) > 2:  # Filter out very short words
                yield (word, 1)
                
    except Exception as e:
        logger.warning(f"Failed to parse log line: {e}")
        # Extract words from raw line as fallback
        words = re.findall(r'\b[a-zA-Z]+\b', log_line.lower())
        for word in words:
            if len(word) > 2:
                yield (word, 1)

def word_count_reducer(key: str, values: List[int]) -> Tuple[str, int]:
    """Reduce function for word count analysis"""
    return (key, sum(values))

def pattern_frequency_mapper(log_line: str) -> Iterator[Tuple[str, int]]:
    """Map function for pattern frequency analysis"""
    try:
        # Common log patterns to detect
        patterns = {
            'error_pattern': r'(error|exception|failed|failure)',
            'warning_pattern': r'(warning|warn)',
            'info_pattern': r'(info|information)',
            'debug_pattern': r'(debug|trace)',
            'ip_address': r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b',
            'http_status': r'\b[1-5][0-9]{2}\b',
            'timestamp': r'\d{4}-\d{2}-\d{2}.\d{2}:\d{2}:\d{2}',
            'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        }
        
        for pattern_name, pattern_regex in patterns.items():
            matches = re.findall(pattern_regex, log_line.lower())
            for match in matches:
                if isinstance(match, tuple):
                    match = match[0]  # Take first group if tuple
                yield (f"{pattern_name}:{match}", 1)
                
    except Exception as e:
        logger.warning(f"Failed to analyze patterns in log line: {e}")

def pattern_frequency_reducer(key: str, values: List[int]) -> Tuple[str, int]:
    """Reduce function for pattern frequency analysis"""
    return (key, sum(values))

def service_distribution_mapper(log_line: str) -> Iterator[Tuple[str, int]]:
    """Map function for service distribution analysis"""
    try:
        if log_line.strip().startswith('{'):
            # JSON log format
            log_data = json.loads(log_line)
            service = log_data.get('service', 'unknown')
            level = log_data.get('level', 'unknown')
            yield (f"service:{service}", 1)
            yield (f"level:{level}", 1)
            yield (f"service_level:{service}_{level}", 1)
        else:
            # Try to extract service from log line patterns
            # Common patterns: [SERVICE] or SERVICE: or /api/SERVICE/
            service_patterns = [
                r'\[([A-Za-z0-9_-]+)\]',
                r'([A-Za-z0-9_-]+):',
                r'/api/([A-Za-z0-9_-]+)/',
                r'service[=:]([A-Za-z0-9_-]+)'
            ]
            
            for pattern in service_patterns:
                matches = re.findall(pattern, log_line, re.IGNORECASE)
                for match in matches:
                    yield (f"service:{match}", 1)
                    break  # Only use first match
            else:
                yield ("service:unknown", 1)
                
    except Exception as e:
        logger.warning(f"Failed to analyze service distribution: {e}")
        yield ("service:parse_error", 1)

def service_distribution_reducer(key: str, values: List[int]) -> Tuple[str, int]:
    """Reduce function for service distribution analysis"""
    return (key, sum(values))

# Combined analyzer for comprehensive log analysis
def comprehensive_log_mapper(log_line: str) -> Iterator[Tuple[str, int]]:
    """Combined mapper for comprehensive log analysis"""
    # Word count analysis
    for word, count in word_count_mapper(log_line):
        yield (f"word:{word}", count)
    
    # Pattern frequency analysis
    for pattern, count in pattern_frequency_mapper(log_line):
        yield (f"pattern:{pattern}", count)
    
    # Service distribution analysis
    for service, count in service_distribution_mapper(log_line):
        yield (f"distribution:{service}", count)

def comprehensive_log_reducer(key: str, values: List[int]) -> Tuple[str, int]:
    """Combined reducer for comprehensive log analysis"""
    return (key, sum(values))
