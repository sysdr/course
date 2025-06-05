"""
Schema Validator
Validates parsed logs against unified schema before output
"""

from datetime import datetime
from typing import Dict, Any, List, Optional, Union
from config.compatibility_config import config

class SchemaValidator:
    """Validates log entries against the unified schema"""
    
    def __init__(self):
        self.schema = config.unified_schema
        self.required_fields = self.schema['required_fields']
        self.optional_fields = self.schema['optional_fields'] 
        self.level_mapping = self.schema['level_mapping']
        
    def validate(self, log_entry: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate and normalize a single log entry
        
        Args:
            log_entry: Parsed log entry to validate
            
        Returns:
            Validation result with status and normalized entry
        """
        if not isinstance(log_entry, dict):
            return {
                'valid': False,
                'errors': ['Log entry must be a dictionary'],
                'entry': None
            }
        
        errors = []
        normalized_entry = log_entry.copy()
        
        # Check required fields
        for field in self.required_fields:
            if field not in log_entry or log_entry[field] is None:
                errors.append(f"Missing required field: {field}")
        
        # Validate and normalize timestamp
        timestamp_result = self._validate_timestamp(log_entry.get('timestamp'))
        if timestamp_result['valid']:
            normalized_entry['timestamp'] = timestamp_result['normalized']
        else:
            errors.extend(timestamp_result['errors'])
        
        # Validate and normalize level
        level_result = self._validate_level(log_entry.get('level'))
        if level_result['valid']:
            normalized_entry['level'] = level_result['normalized']
        else:
            errors.extend(level_result['errors'])
        
        # Validate message
        message_result = self._validate_message(log_entry.get('message'))
        if message_result['valid']:
            normalized_entry['message'] = message_result['normalized']
        else:
            errors.extend(message_result['errors'])
        
        # Validate source_format
        if 'source_format' not in log_entry:
            errors.append("Missing source_format field")
        
        # Normalize optional fields
        for field in self.optional_fields:
            if field in log_entry:
                normalized_value = self._normalize_field(field, log_entry[field])
                normalized_entry[field] = normalized_value
        
        return {
            'valid': len(errors) == 0,
            'errors': errors,
            'entry': normalized_entry if len(errors) == 0 else None
        }
    
    def _validate_timestamp(self, timestamp: Any) -> Dict[str, Any]:
        """Validate and normalize timestamp field"""
        if not timestamp:
            return {
                'valid': False,
                'errors': ['Timestamp cannot be empty'],
                'normalized': None
            }
        
        if isinstance(timestamp, str):
            try:
                # Try to parse ISO format
                dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                return {
                    'valid': True,
                    'errors': [],
                    'normalized': dt.isoformat()
                }
            except ValueError:
                return {
                    'valid': False,
                    'errors': [f'Invalid timestamp format: {timestamp}'],
                    'normalized': None
                }
        
        return {
            'valid': False,
            'errors': [f'Timestamp must be string, got {type(timestamp)}'],
            'normalized': None
        }
    
    def _validate_level(self, level: Any) -> Dict[str, Any]:
        """Validate and normalize log level"""
        if not level:
            return {
                'valid': False,
                'errors': ['Level cannot be empty'],
                'normalized': None
            }
        
        if not isinstance(level, str):
            level = str(level)
        
        level = level.upper()
        
        # Map level if needed
        normalized_level = self.level_mapping.get(level, level)
        
        # Check if it's a valid level
        valid_levels = ['CRITICAL', 'ERROR', 'WARNING', 'INFO', 'DEBUG']
        if normalized_level not in valid_levels:
            return {
                'valid': False,
                'errors': [f'Invalid level: {level}. Must be one of {valid_levels}'],
                'normalized': None
            }
        
        return {
            'valid': True,
            'errors': [],
            'normalized': normalized_level
        }
    
    def _validate_message(self, message: Any) -> Dict[str, Any]:
        """Validate and normalize message field"""
        if message is None:
            return {
                'valid': False,
                'errors': ['Message cannot be None'],
                'normalized': None
            }
        
        if not isinstance(message, str):
            message = str(message)
        
        # Basic sanitization
        message = message.strip()
        
        if not message:
            return {
                'valid': False,
                'errors': ['Message cannot be empty after normalization'],
                'normalized': None
            }
        
        return {
            'valid': True,
            'errors': [],
            'normalized': message
        }
    
    def _normalize_field(self, field_name: str, value: Any) -> Any:
        """Normalize optional field values"""
        if value is None:
            return None
        
        # Convert to string for most fields
        if field_name in ['hostname', 'facility', 'process_id', 'user_id']:
            return str(value).strip() if str(value).strip() else None
        
        return value
    
    def batch_validate(self, log_entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Validate multiple log entries
        
        Args:
            log_entries: List of log entries to validate
            
        Returns:
            Summary of validation results
        """
        results = []
        valid_entries = []
        total_errors = []
        
        for i, entry in enumerate(log_entries):
            result = self.validate(entry)
            results.append(result)
            
            if result['valid']:
                valid_entries.append(result['entry'])
            else:
                total_errors.extend([f"Entry {i}: {error}" for error in result['errors']])
        
        return {
            'total_entries': len(log_entries),
            'valid_entries': len(valid_entries),
            'invalid_entries': len(log_entries) - len(valid_entries),
            'success_rate': len(valid_entries) / len(log_entries) if log_entries else 0,
            'valid_logs': valid_entries,
            'errors': total_errors,
            'individual_results': results
        }
