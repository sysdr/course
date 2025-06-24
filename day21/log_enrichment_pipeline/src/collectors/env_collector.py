"""
Environment configuration collector for log enrichment pipeline.
Gathers environment variables and configuration data.
"""

import os
from typing import Dict, Any, Set
import logging

logger = logging.getLogger(__name__)


class EnvironmentCollector:
    """
    Collects environment and configuration metadata.
    
    This collector gathers relevant environment variables and
    configuration that provides context for log entries.
    """
    
    def __init__(self, include_patterns: Set[str] = None, exclude_patterns: Set[str] = None):
        """
        Initialize environment collector with filtering.
        
        Args:
            include_patterns: Environment variable prefixes to include
            exclude_patterns: Environment variable patterns to exclude
        """
        self.include_patterns = include_patterns or {
            'APP_', 'SERVICE_', 'ENVIRONMENT', 'DEPLOY_', 'VERSION',
            'REGION', 'ZONE', 'CLUSTER', 'NAMESPACE', 'POD_'
        }
        self.exclude_patterns = exclude_patterns or {
            'PASSWORD', 'SECRET', 'KEY', 'TOKEN', 'PRIVATE'
        }
        
    def collect(self) -> Dict[str, Any]:
        """
        Collect environment metadata.
        
        Returns:
            Dictionary containing environment information
        """
        try:
            env_vars = self._collect_environment_variables()
            return {
                'environment_type': os.environ.get('ENVIRONMENT', 'development'),
                'service_version': os.environ.get('SERVICE_VERSION', 'unknown'),
                'deployment_id': os.environ.get('DEPLOYMENT_ID', 'unknown'),
                'region': os.environ.get('REGION', 'unknown'),
                'availability_zone': os.environ.get('AVAILABILITY_ZONE', 'unknown'),
                'cluster_name': os.environ.get('CLUSTER_NAME', 'unknown'),
                'namespace': os.environ.get('NAMESPACE', 'default'),
                'environment_variables': env_vars,
                'working_directory': os.getcwd(),
                'process_id': os.getpid(),
            }
        except Exception as e:
            logger.warning(f"Failed to collect environment metadata: {e}")
            return {
                'environment_type': 'unknown',
                'service_version': 'unknown',
                'error': 'env_collection_failed'
            }
    
    def _collect_environment_variables(self) -> Dict[str, str]:
        """Collect filtered environment variables."""
        env_vars = {}
        
        for key, value in os.environ.items():
            # Check if we should include this variable
            if self._should_include_env_var(key):
                env_vars[key] = value
                
        return env_vars
    
    def _should_include_env_var(self, key: str) -> bool:
        """Determine if an environment variable should be included."""
        key_upper = key.upper()
        
        # Exclude sensitive variables
        for exclude_pattern in self.exclude_patterns:
            if exclude_pattern.upper() in key_upper:
                return False
        
        # Include variables matching our patterns
        for include_pattern in self.include_patterns:
            if key_upper.startswith(include_pattern.upper()):
                return True
                
        return False
