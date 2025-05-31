"""
JSON formatter for enriched log output.
"""

import json
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)


class JSONFormatter:
    """
    Formats enriched log entries as structured JSON.
    
    This formatter ensures consistent output format and handles
    serialization of complex data types.
    """
    
    def __init__(self, pretty_print: bool = False):
        """
        Initialize JSON formatter.
        
        Args:
            pretty_print: Whether to format JSON with indentation
        """
        self.pretty_print = pretty_print
    
    def format(self, enriched_log: Dict[str, Any]) -> str:
        """
        Format enriched log as JSON string.
        
        Args:
            enriched_log: The enriched log dictionary
            
        Returns:
            JSON formatted string
        """
        try:
            if self.pretty_print:
                return json.dumps(enriched_log, indent=2, default=self._json_serializer)
            else:
                return json.dumps(enriched_log, separators=(',', ':'), default=self._json_serializer)
        except Exception as e:
            logger.error(f"Failed to format log as JSON: {e}")
            # Return minimal fallback
            return json.dumps({
                'message': str(enriched_log.get('message', 'unknown')),
                'formatting_error': str(e),
                'timestamp': enriched_log.get('timestamp', 'unknown')
            })
    
    def _json_serializer(self, obj: Any) -> str:
        """Custom JSON serializer for complex types."""
        if hasattr(obj, 'isoformat'):
            return obj.isoformat()
        return str(obj)
