"""
System metadata collector for log enrichment pipeline.
Gathers static system information with intelligent caching.
"""

import socket
import platform
import os
import time
from typing import Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)


class SystemCollector:
    """
    Collects system-level metadata that rarely changes.
    
    This collector focuses on gathering information that's stable
    during application runtime, like hostname and OS details.
    """
    
    def __init__(self, cache_ttl: int = 300):
        """
        Initialize system collector with caching.
        
        Args:
            cache_ttl: Cache time-to-live in seconds (default: 5 minutes)
        """
        self._cache: Dict[str, Any] = {}
        self._cache_ttl = cache_ttl
        self._last_collected: Optional[float] = None
        
    def collect(self) -> Dict[str, Any]:
        """
        Collect system metadata with caching for performance.
        
        Returns:
            Dictionary containing system information
        """
        current_time = time.time()
        
        # Check if we need to refresh cache
        if (self._last_collected is None or 
            current_time - self._last_collected > self._cache_ttl):
            self._refresh_cache()
            self._last_collected = current_time
            
        return self._cache.copy()
    
    def _refresh_cache(self) -> None:
        """Refresh the system information cache."""
        try:
            self._cache = {
                'hostname': self._get_hostname(),
                'platform': platform.system(),
                'platform_release': platform.release(),
                'platform_version': platform.version(),
                'architecture': platform.machine(),
                'processor': platform.processor(),
                'python_version': platform.python_version(),
                'environment': os.environ.get('ENVIRONMENT', 'unknown'),
                'service_name': os.environ.get('SERVICE_NAME', 'log-enrichment'),
                'node_id': self._get_node_id(),
            }
            logger.debug("System metadata cache refreshed")
        except Exception as e:
            logger.warning(f"Failed to collect some system metadata: {e}")
            # Provide minimal fallback data
            self._cache = {
                'hostname': 'unknown',
                'platform': 'unknown',
                'environment': 'unknown',
                'service_name': 'log-enrichment',
            }
    
    def _get_hostname(self) -> str:
        """Get system hostname with fallback."""
        try:
            return socket.gethostname()
        except Exception:
            return os.environ.get('HOSTNAME', 'unknown')
    
    def _get_node_id(self) -> str:
        """Generate or retrieve a node identifier."""
        # Try to get from environment first
        node_id = os.environ.get('NODE_ID')
        if node_id:
            return node_id
            
        # Fallback to hostname-based ID
        try:
            hostname = self._get_hostname()
            return f"node-{hash(hostname) % 10000:04d}"
        except Exception:
            return "node-0000"
