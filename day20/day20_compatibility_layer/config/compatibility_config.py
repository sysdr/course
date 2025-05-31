"""
Configuration for the Compatibility Layer System
Manages adapter settings, validation rules, and output formats
"""

import os
from typing import Dict, List, Any

class CompatibilityConfig:
    """Central configuration for all compatibility layer components"""
    
    def __init__(self):
        self.base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        # Adapter configurations
        self.adapters = {
            'syslog': {
                'priority_parsing': True,
                'timestamp_formats': [
                    '%b %d %H:%M:%S',  # Oct 11 22:14:15
                    '%Y-%m-%dT%H:%M:%S.%fZ',  # ISO format
                    '%Y-%m-%dT%H:%M:%S%z'     # With timezone
                ],
                'facilities': {
                    0: 'kernel', 1: 'user', 2: 'mail', 3: 'daemon',
                    4: 'auth', 5: 'syslog', 6: 'lpr', 7: 'news'
                },
                'severities': {
                    0: 'EMERGENCY', 1: 'ALERT', 2: 'CRITICAL', 3: 'ERROR',
                    4: 'WARNING', 5: 'NOTICE', 6: 'INFO', 7: 'DEBUG'
                }
            },
            'journald': {
                'required_fields': ['__REALTIME_TIMESTAMP', 'MESSAGE'],
                'optional_fields': ['_PID', '_UID', '_GID', '_COMM', '_EXE'],
                'timestamp_format': 'microseconds_since_epoch'
            }
        }
        
        # Output schema configuration
        self.unified_schema = {
            'required_fields': ['timestamp', 'level', 'message', 'source_format'],
            'optional_fields': ['facility', 'hostname', 'process_id', 'user_id'],
            'timestamp_format': 'iso8601',
            'level_mapping': {
                'EMERGENCY': 'CRITICAL',
                'ALERT': 'CRITICAL', 
                'CRITICAL': 'CRITICAL',
                'ERROR': 'ERROR',
                'WARNING': 'WARNING',
                'NOTICE': 'INFO',
                'INFO': 'INFO',
                'DEBUG': 'DEBUG'
            }
        }
        
        # Performance settings
        self.performance = {
            'max_buffer_size': 10000,  # logs per buffer
            'batch_size': 100,         # logs per batch
            'timeout_seconds': 5,      # processing timeout
            'max_memory_mb': 100       # memory limit
        }
        
        # File paths
        self.paths = {
            'sample_logs': os.path.join(self.base_dir, 'logs', 'samples'),
            'output_logs': os.path.join(self.base_dir, 'logs', 'output'),
            'error_logs': os.path.join(self.base_dir, 'logs', 'errors'),
            'schemas': os.path.join(self.base_dir, 'config', 'schemas')
        }

# Global configuration instance
config = CompatibilityConfig()
