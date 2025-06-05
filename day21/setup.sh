#!/bin/bash

# ===================================================================
# Log Enrichment Pipeline - One-Click Setup Script
# Day 21: 254-Day Hands-On System Design Course
# ===================================================================

set -e  # Exit on any error

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="log_enrichment_pipeline"
PYTHON_VERSION="3.13"
PORT="8080"

# Function to print colored output
print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ===================================================================
# STEP 1: Environment Validation and Setup
# ===================================================================
print_step "Validating environment and dependencies..."

# Check Python installation
if ! command_exists python3; then
    print_error "Python 3 is required but not installed. Please install Python 3.9 or later."
    exit 1
fi

PYTHON_VER=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
print_success "Found Python $PYTHON_VER"

# Check if pip is available
if ! command_exists pip3; then
    print_error "pip3 is required but not installed."
    exit 1
fi

# Check if we can create virtual environments
if ! python3 -c "import venv" 2>/dev/null; then
    print_error "Python venv module is required but not available."
    exit 1
fi

print_success "Environment validation completed"

# ===================================================================
# STEP 2: Project Structure Creation
# ===================================================================
print_step "Creating project structure..."

# Remove existing project directory if it exists
if [ -d "$PROJECT_NAME" ]; then
    print_warning "Project directory exists. Removing..."
    rm -rf "$PROJECT_NAME"
fi

# Create main project directory
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Create directory structure
mkdir -p src/collectors src/enrichers src/formatters tests demo config

# Create __init__.py files for Python packages
touch src/__init__.py src/collectors/__init__.py src/enrichers/__init__.py src/formatters/__init__.py tests/__init__.py

print_success "Project structure created"

# ===================================================================
# STEP 3: Core Implementation Files Creation
# ===================================================================
print_step "Creating core implementation files..."

# Create requirements.txt
cat > requirements.txt << 'EOF'
# Core dependencies for log enrichment pipeline
flask==2.3.3
pyyaml==6.0.1
psutil==5.9.5
pytest==7.4.2
pytest-cov==4.1.0
requests==2.31.0
python-json-logger==2.0.7

# Development dependencies
black==23.7.0
flake8==6.0.0
mypy==1.5.1
EOF

# Create system collector
cat > src/collectors/system_collector.py << 'EOF'
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
EOF

# Create performance collector
cat > src/collectors/performance_collector.py << 'EOF'
"""
Performance metrics collector for log enrichment pipeline.
Gathers real-time system performance data.
"""

import psutil
import time
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)


class PerformanceCollector:
    """
    Collects real-time performance metrics.
    
    Unlike system information, performance data changes frequently,
    so we use minimal caching and focus on efficient collection.
    """
    
    def __init__(self, cache_duration: float = 1.0):
        """
        Initialize performance collector.
        
        Args:
            cache_duration: How long to cache metrics in seconds
        """
        self._cache_duration = cache_duration
        self._last_collection: float = 0
        self._cached_metrics: Dict[str, Any] = {}
        
    def collect(self) -> Dict[str, Any]:
        """
        Collect current performance metrics.
        
        Returns:
            Dictionary containing performance data
        """
        current_time = time.time()
        
        # Use short-term caching to avoid overwhelming the system
        if current_time - self._last_collection > self._cache_duration:
            self._cached_metrics = self._collect_fresh_metrics()
            self._last_collection = current_time
            
        return self._cached_metrics.copy()
    
    def _collect_fresh_metrics(self) -> Dict[str, Any]:
        """Collect fresh performance metrics."""
        try:
            # CPU metrics
            cpu_percent = psutil.cpu_percent(interval=None)
            cpu_count = psutil.cpu_count()
            
            # Memory metrics
            memory = psutil.virtual_memory()
            
            # Disk metrics for root partition
            disk = psutil.disk_usage('/')
            
            # Network metrics (basic)
            network = psutil.net_io_counters()
            
            return {
                'cpu_percent': round(cpu_percent, 1),
                'cpu_count': cpu_count,
                'memory_total_gb': round(memory.total / (1024**3), 2),
                'memory_used_gb': round(memory.used / (1024**3), 2),
                'memory_percent': round(memory.percent, 1),
                'disk_total_gb': round(disk.total / (1024**3), 2),
                'disk_used_gb': round(disk.used / (1024**3), 2),
                'disk_percent': round((disk.used / disk.total) * 100, 1),
                'network_bytes_sent': network.bytes_sent,
                'network_bytes_recv': network.bytes_recv,
                'load_average': self._get_load_average(),
                'uptime_seconds': time.time() - psutil.boot_time(),
            }
        except Exception as e:
            logger.warning(f"Failed to collect performance metrics: {e}")
            return {
                'cpu_percent': 0.0,
                'memory_percent': 0.0,
                'disk_percent': 0.0,
                'error': 'metrics_collection_failed'
            }
    
    def _get_load_average(self) -> Dict[str, float]:
        """Get system load average if available."""
        try:
            if hasattr(psutil, 'getloadavg'):
                load1, load5, load15 = psutil.getloadavg()
                return {
                    'load_1m': round(load1, 2),
                    'load_5m': round(load5, 2),
                    'load_15m': round(load15, 2)
                }
        except (AttributeError, OSError):
            pass
        return {'load_1m': 0.0, 'load_5m': 0.0, 'load_15m': 0.0}
EOF

# Create environment collector
cat > src/collectors/env_collector.py << 'EOF'
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
EOF

# Create rule engine
cat > src/enrichers/rule_engine.py << 'EOF'
"""
Rule engine for determining which metadata to apply to log entries.
"""

import re
from typing import Dict, Any, List
import logging
import yaml

logger = logging.getLogger(__name__)


class EnrichmentRule:
    """Represents a single enrichment rule."""
    
    def __init__(self, name: str, conditions: Dict[str, Any], actions: Dict[str, Any]):
        self.name = name
        self.conditions = conditions
        self.actions = actions
    
    def matches(self, log_entry: Dict[str, Any]) -> bool:
        """Check if this rule matches the given log entry."""
        for condition_type, condition_value in self.conditions.items():
            if condition_type == 'log_level':
                if not self._check_log_level(log_entry.get('level', ''), condition_value):
                    return False
            elif condition_type == 'message_contains':
                if not self._check_message_contains(log_entry.get('message', ''), condition_value):
                    return False
            elif condition_type == 'source_matches':
                if not self._check_source_matches(log_entry.get('source', ''), condition_value):
                    return False
        return True
    
    def _check_log_level(self, log_level: str, target_levels: List[str]) -> bool:
        """Check if log level matches target levels."""
        return log_level.upper() in [level.upper() for level in target_levels]
    
    def _check_message_contains(self, message: str, patterns: List[str]) -> bool:
        """Check if message contains any of the patterns."""
        for pattern in patterns:
            if pattern.lower() in message.lower():
                return True
        return False
    
    def _check_source_matches(self, source: str, patterns: List[str]) -> bool:
        """Check if source matches any of the patterns."""
        for pattern in patterns:
            if re.search(pattern, source, re.IGNORECASE):
                return True
        return False


class RuleEngine:
    """
    Determines which enrichment metadata to apply to each log entry.
    
    The rule engine uses configurable rules to decide what metadata
    should be attached to different types of log entries.
    """
    
    def __init__(self, rules_config: str = None):
        """
        Initialize rule engine with configuration.
        
        Args:
            rules_config: Path to YAML rules configuration file
        """
        self.rules: List[EnrichmentRule] = []
        self._load_default_rules()
        
        if rules_config:
            self._load_rules_from_file(rules_config)
    
    def apply_rules(self, log_entry: Dict[str, Any], available_metadata: Dict[str, Any]) -> Dict[str, Any]:
        """
        Apply enrichment rules to determine final metadata set.
        
        Args:
            log_entry: The log entry to enrich
            available_metadata: All available metadata from collectors
            
        Returns:
            Dictionary containing selected metadata for this log entry
        """
        # Start with always-included metadata
        enrichment_data = {
            'enrichment_timestamp': available_metadata.get('collection_timestamp'),
            'hostname': available_metadata.get('system', {}).get('hostname', 'unknown'),
            'service_name': available_metadata.get('system', {}).get('service_name', 'unknown'),
        }
        
        # Apply matching rules
        for rule in self.rules:
            if rule.matches(log_entry):
                logger.debug(f"Applying rule: {rule.name}")
                self._apply_rule_actions(rule, enrichment_data, available_metadata)
        
        return enrichment_data
    
    def _apply_rule_actions(self, rule: EnrichmentRule, enrichment_data: Dict[str, Any], 
                           available_metadata: Dict[str, Any]) -> None:
        """Apply the actions specified in a rule."""
        for action_type, action_config in rule.actions.items():
            if action_type == 'include_performance':
                if action_config:
                    performance_data = available_metadata.get('performance', {})
                    enrichment_data.update({
                        'cpu_percent': performance_data.get('cpu_percent'),
                        'memory_percent': performance_data.get('memory_percent'),
                        'disk_percent': performance_data.get('disk_percent'),
                    })
            
            elif action_type == 'include_environment':
                if action_config:
                    env_data = available_metadata.get('environment', {})
                    enrichment_data.update({
                        'environment_type': env_data.get('environment_type'),
                        'service_version': env_data.get('service_version'),
                        'region': env_data.get('region'),
                    })
            
            elif action_type == 'include_detailed_system':
                if action_config:
                    system_data = available_metadata.get('system', {})
                    enrichment_data.update({
                        'platform': system_data.get('platform'),
                        'node_id': system_data.get('node_id'),
                        'architecture': system_data.get('architecture'),
                    })
    
    def _load_default_rules(self) -> None:
        """Load default enrichment rules."""
        # Rule 1: Always include basic context for ERROR logs
        error_rule = EnrichmentRule(
            name="error_enrichment",
            conditions={
                'log_level': ['ERROR', 'CRITICAL', 'FATAL']
            },
            actions={
                'include_performance': True,
                'include_environment': True,
                'include_detailed_system': True
            }
        )
        
        # Rule 2: Include performance data for WARN logs
        warning_rule = EnrichmentRule(
            name="warning_enrichment",
            conditions={
                'log_level': ['WARN', 'WARNING']
            },
            actions={
                'include_performance': True,
                'include_environment': True
            }
        )
        
        # Rule 3: Minimal enrichment for INFO logs
        info_rule = EnrichmentRule(
            name="info_enrichment",
            conditions={
                'log_level': ['INFO']
            },
            actions={
                'include_environment': True
            }
        )
        
        self.rules = [error_rule, warning_rule, info_rule]
    
    def _load_rules_from_file(self, rules_file: str) -> None:
        """Load rules from YAML configuration file."""
        try:
            with open(rules_file, 'r') as f:
                config = yaml.safe_load(f)
                
            for rule_config in config.get('rules', []):
                rule = EnrichmentRule(
                    name=rule_config['name'],
                    conditions=rule_config['conditions'],
                    actions=rule_config['actions']
                )
                self.rules.append(rule)
                
            logger.info(f"Loaded {len(self.rules)} enrichment rules from {rules_file}")
        except Exception as e:
            logger.warning(f"Failed to load rules from {rules_file}: {e}")
EOF

print_success "Core implementation files created"

# ===================================================================
# STEP 4: Create Main Pipeline and Demo Components
# ===================================================================
print_step "Creating main pipeline and demo components..."

# Create main pipeline orchestrator
cat > src/pipeline.py << 'EOF'
"""
Main log enrichment pipeline orchestrator.
"""

import time
import json
from typing import Dict, Any, Optional
import logging
from datetime import datetime, timezone

from src.collectors.system_collector import SystemCollector
from src.collectors.performance_collector import PerformanceCollector
from src.collectors.env_collector import EnvironmentCollector
from src.enrichers.rule_engine import RuleEngine
from src.formatters.json_formatter import JSONFormatter

logger = logging.getLogger(__name__)


class LogEnrichmentPipeline:
    """
    Main log enrichment pipeline that coordinates all components.
    
    This class brings together collectors, rule engine, and formatters
    to transform raw log entries into enriched, contextual records.
    """
    
    def __init__(self, config: Dict[str, Any] = None):
        """
        Initialize the enrichment pipeline.
        
        Args:
            config: Configuration dictionary for pipeline components
        """
        self.config = config or {}
        
        # Initialize collectors
        self.system_collector = SystemCollector()
        self.performance_collector = PerformanceCollector()
        self.env_collector = EnvironmentCollector()
        
        # Initialize rule engine and formatter
        self.rule_engine = RuleEngine()
        self.formatter = JSONFormatter()
        
        # Pipeline statistics
        self.stats = {
            'processed_count': 0,
            'error_count': 0,
            'start_time': time.time()
        }
        
        logger.info("Log enrichment pipeline initialized")
    
    def enrich_log(self, raw_log: str, source: str = "unknown") -> Dict[str, Any]:
        """
        Enrich a single log entry.
        
        Args:
            raw_log: The raw log message
            source: Source identifier for the log
            
        Returns:
            Enriched log entry as dictionary
        """
        start_time = time.time()
        
        try:
            # Parse the incoming log entry
            log_entry = self._parse_log_entry(raw_log, source)
            
            # Collect metadata from all sources
            metadata = self._collect_metadata()
            
            # Apply enrichment rules
            enrichment_data = self.rule_engine.apply_rules(log_entry, metadata)
            
            # Create enriched log record
            enriched_log = self._create_enriched_record(log_entry, enrichment_data)
            
            # Update statistics
            self.stats['processed_count'] += 1
            processing_time = time.time() - start_time
            enriched_log['processing_time_ms'] = round(processing_time * 1000, 2)
            
            logger.debug(f"Enriched log in {processing_time:.3f}s")
            return enriched_log
            
        except Exception as e:
            self.stats['error_count'] += 1
            logger.error(f"Failed to enrich log: {e}")
            
            # Return original log with error information
            return {
                'original_message': raw_log,
                'source': source,
                'timestamp': datetime.now(timezone.utc).isoformat(),
                'enrichment_error': str(e),
                'processing_time_ms': round((time.time() - start_time) * 1000, 2)
            }
    
    def _parse_log_entry(self, raw_log: str, source: str) -> Dict[str, Any]:
        """Parse raw log entry into structured format."""
        # Simple parsing - in production, this would be more sophisticated
        log_entry = {
            'message': raw_log.strip(),
            'source': source,
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'level': self._extract_log_level(raw_log)
        }
        
        return log_entry
    
    def _extract_log_level(self, message: str) -> str:
        """Extract log level from message."""
        message_upper = message.upper()
        for level in ['CRITICAL', 'FATAL', 'ERROR', 'WARN', 'WARNING', 'INFO', 'DEBUG']:
            if level in message_upper:
                return level
        return 'INFO'  # Default level
    
    def _collect_metadata(self) -> Dict[str, Any]:
        """Collect metadata from all collectors."""
        metadata = {
            'collection_timestamp': datetime.now(timezone.utc).isoformat(),
        }
        
        try:
            metadata['system'] = self.system_collector.collect()
        except Exception as e:
            logger.warning(f"System metadata collection failed: {e}")
            metadata['system'] = {}
        
        try:
            metadata['performance'] = self.performance_collector.collect()
        except Exception as e:
            logger.warning(f"Performance metadata collection failed: {e}")
            metadata['performance'] = {}
        
        try:
            metadata['environment'] = self.env_collector.collect()
        except Exception as e:
            logger.warning(f"Environment metadata collection failed: {e}")
            metadata['environment'] = {}
        
        return metadata
    
    def _create_enriched_record(self, log_entry: Dict[str, Any], 
                               enrichment_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create the final enriched log record."""
        enriched_record = {
            # Original log data
            'timestamp': log_entry['timestamp'],
            'level': log_entry['level'],
            'message': log_entry['message'],
            'source': log_entry['source'],
            
            # Enrichment metadata
            **enrichment_data,
            
            # Pipeline metadata
            'enrichment_version': '1.0.0',
            'enriched_at': datetime.now(timezone.utc).isoformat(),
        }
        
        return enriched_record
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get pipeline processing statistics."""
        runtime = time.time() - self.stats['start_time']
        
        return {
            'processed_count': self.stats['processed_count'],
            'error_count': self.stats['error_count'],
            'success_rate': (
                (self.stats['processed_count'] - self.stats['error_count']) / 
                max(self.stats['processed_count'], 1) * 100
            ),
            'runtime_seconds': round(runtime, 2),
            'average_throughput': round(self.stats['processed_count'] / max(runtime, 1), 2),
        }
EOF

# Create JSON formatter
cat > src/formatters/json_formatter.py << 'EOF'
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
EOF

print_success "Main pipeline and formatter created"

# ===================================================================
# STEP 5: Create Demo Application
# ===================================================================
print_step "Creating demo web application..."

# Create demo server
cat > demo/demo_server.py << 'EOF'
"""
Demo web server for log enrichment pipeline.
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from flask import Flask, render_template, request, jsonify
import json
import logging
from datetime import datetime

from src.pipeline import LogEnrichmentPipeline

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Initialize enrichment pipeline
pipeline = LogEnrichmentPipeline()

@app.route('/')
def index():
    """Main demo page."""
    return render_template('index.html')

@app.route('/api/enrich', methods=['POST'])
def enrich_log():
    """Enrich a log entry via API."""
    try:
        data = request.get_json()
        raw_log = data.get('log_message', '')
        source = data.get('source', 'demo')
        
        if not raw_log:
            return jsonify({'error': 'No log message provided'}), 400
        
        # Enrich the log
        enriched = pipeline.enrich_log(raw_log, source)
        
        return jsonify({
            'success': True,
            'enriched_log': enriched,
            'original_log': raw_log
        })
        
    except Exception as e:
        logger.error(f"API enrichment failed: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/stats')
def get_stats():
    """Get pipeline statistics."""
    return jsonify(pipeline.get_statistics())

@app.route('/api/sample-logs')
def get_sample_logs():
    """Get sample log entries for testing."""
    sample_logs = [
        "INFO: User login successful for user_id=12345",
        "ERROR: Database connection timeout after 30 seconds",
        "WARN: High memory usage detected: 89% of available memory",
        "DEBUG: Processing payment transaction id=abc123",
        "CRITICAL: System disk space critically low: 95% full",
        "INFO: Cache refresh completed in 150ms",
        "ERROR: Failed to authenticate user: invalid credentials",
        "WARN: API rate limit approaching for client_id=xyz789"
    ]
    return jsonify(sample_logs)

if __name__ == '__main__':
    print("Starting Log Enrichment Demo Server...")
    print("Open http://localhost:8080 in your browser")
    app.run(host='0.0.0.0', port=8080, debug=True)
EOF

# Create demo HTML template directory and file
mkdir -p demo/templates

cat > demo/templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Log Enrichment Pipeline Demo</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            color: #2c3e50;
        }
        .demo-section {
            margin-bottom: 30px;
            padding: 20px;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            background-color: #fafafa;
        }
        .input-group {
            margin-bottom: 15px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
            color: #34495e;
        }
        input, textarea, select {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
        }
        button {
            background-color: #3498db;
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
            margin-right: 10px;
        }
        button:hover {
            background-color: #2980b9;
        }
        .sample-button {
            background-color: #27ae60;
        }
        .sample-button:hover {
            background-color: #229954;
        }
        .output {
            background-color: #2c3e50;
            color: #ecf0f1;
            padding: 15px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 12px;
            white-space: pre-wrap;
            max-height: 400px;
            overflow-y: auto;
            margin-top: 15px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-value {
            font-size: 24px;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .error {
            color: #e74c3c;
            background-color: #fdf2f2;
            padding: 10px;
            border-radius: 4px;
            margin-top: 10px;
        }
        .success {
            color: #27ae60;
            background-color: #f0f9f0;
            padding: 10px;
            border-radius: 4px;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Log Enrichment Pipeline Demo</h1>
            <p>Day 21: 254-Day Hands-On System Design Course</p>
        </div>

        <div class="demo-section">
            <h2>Log Enrichment Testing</h2>
            <div class="input-group">
                <label for="logMessage">Log Message:</label>
                <textarea id="logMessage" rows="3" placeholder="Enter a log message to enrich...">ERROR: Database connection timeout after 30 seconds</textarea>
            </div>
            <div class="input-group">
                <label for="logSource">Source:</label>
                <input type="text" id="logSource" value="demo-app" placeholder="Source identifier">
            </div>
            <button onclick="enrichLog()">Enrich Log</button>
            <button class="sample-button" onclick="loadSampleLog()">Load Sample</button>
            <button onclick="clearOutput()">Clear Output</button>
            
            <div id="output" class="output"></div>
            <div id="message"></div>
        </div>

        <div class="demo-section">
            <h2>Pipeline Statistics</h2>
            <button onclick="loadStats()">Refresh Stats</button>
            <div id="stats" class="stats"></div>
        </div>
    </div>

    <script>
        let sampleLogs = [];
        
        // Load sample logs on page load
        fetch('/api/sample-logs')
            .then(response => response.json())
            .then(data => {
                sampleLogs = data;
            })
            .catch(error => console.error('Failed to load sample logs:', error));

        function enrichLog() {
            const logMessage = document.getElementById('logMessage').value;
            const logSource = document.getElementById('logSource').value;
            const outputDiv = document.getElementById('output');
            const messageDiv = document.getElementById('message');
            
            if (!logMessage.trim()) {
                showMessage('Please enter a log message', 'error');
                return;
            }
            
            // Show loading
            outputDiv.textContent = 'Processing...';
            messageDiv.innerHTML = '';
            
            fetch('/api/enrich', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    log_message: logMessage,
                    source: logSource
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    const formatted = JSON.stringify(data.enriched_log, null, 2);
                    outputDiv.textContent = formatted;
                    showMessage('Log enriched successfully!', 'success');
                } else {
                    outputDiv.textContent = 'Error: ' + data.error;
                    showMessage('Enrichment failed: ' + data.error, 'error');
                }
            })
            .catch(error => {
                outputDiv.textContent = 'Network error: ' + error;
                showMessage('Network error occurred', 'error');
            });
        }
        
        function loadSampleLog() {
            if (sampleLogs.length > 0) {
                const randomLog = sampleLogs[Math.floor(Math.random() * sampleLogs.length)];
                document.getElementById('logMessage').value = randomLog;
            }
        }
        
        function clearOutput() {
            document.getElementById('output').textContent = '';
            document.getElementById('message').innerHTML = '';
        }
        
        function loadStats() {
            fetch('/api/stats')
                .then(response => response.json())
                .then(data => {
                    const statsDiv = document.getElementById('stats');
                    statsDiv.innerHTML = `
                        <div class="stat-card">
                            <div class="stat-value">${data.processed_count}</div>
                            <div>Logs Processed</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value">${data.error_count}</div>
                            <div>Errors</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value">${data.success_rate.toFixed(1)}%</div>
                            <div>Success Rate</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value">${data.average_throughput}</div>
                            <div>Logs/Second</div>
                        </div>
                    `;
                })
                .catch(error => {
                    console.error('Failed to load stats:', error);
                });
        }
        
        function showMessage(text, type) {
            const messageDiv = document.getElementById('message');
            messageDiv.innerHTML = `<div class="${type}">${text}</div>`;
        }
        
        // Load stats on page load
        loadStats();
        
        // Auto-refresh stats every 30 seconds
        setInterval(loadStats, 30000);
    </script>
</body>
</html>
EOF

print_success "Demo web application created"

# ===================================================================
# STEP 6: Create Configuration and Tests
# ===================================================================
print_step "Creating configuration files and tests..."

# Create enrichment rules configuration
cat > config/enrichment_rules.yaml << 'EOF'
# Log Enrichment Rules Configuration
# Defines which metadata to include based on log characteristics

rules:
  - name: "critical_error_enrichment"
    conditions:
      log_level: ["CRITICAL", "FATAL"]
      message_contains: ["error", "fail", "crash", "panic"]
    actions:
      include_performance: true
      include_environment: true
      include_detailed_system: true
      include_network: true

  - name: "database_error_enrichment"
    conditions:
      message_contains: ["database", "db", "sql", "connection", "timeout"]
    actions:
      include_performance: true
      include_environment: true

  - name: "authentication_enrichment"
    conditions:
      message_contains: ["auth", "login", "user", "session", "token"]
    actions:
      include_environment: true
      include_security_context: true

  - name: "performance_warning_enrichment"
    conditions:
      log_level: ["WARN", "WARNING"]
      message_contains: ["memory", "cpu", "disk", "slow", "timeout"]
    actions:
      include_performance: true

  - name: "default_info_enrichment"
    conditions:
      log_level: ["INFO"]
    actions:
      include_environment: true
EOF

# Create comprehensive test suite
cat > tests/test_collectors.py << 'EOF'
"""
Tests for metadata collectors.
"""

import unittest
from unittest.mock import patch, MagicMock
import sys
import os

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.collectors.system_collector import SystemCollector
from src.collectors.performance_collector import PerformanceCollector
from src.collectors.env_collector import EnvironmentCollector


class TestSystemCollector(unittest.TestCase):
    """Test system metadata collector."""
    
    def setUp(self):
        self.collector = SystemCollector(cache_ttl=1)
    
    def test_collect_returns_dict(self):
        """Test that collect returns a dictionary."""
        result = self.collector.collect()
        self.assertIsInstance(result, dict)
    
    def test_required_fields_present(self):
        """Test that required fields are present in collected data."""
        result = self.collector.collect()
        required_fields = ['hostname', 'platform', 'service_name']
        for field in required_fields:
            self.assertIn(field, result)
    
    @patch('socket.gethostname')
    def test_hostname_fallback(self, mock_hostname):
        """Test hostname fallback when socket.gethostname fails."""
        mock_hostname.side_effect = Exception("Network error")
        with patch.dict(os.environ, {'HOSTNAME': 'test-host'}):
            result = self.collector.collect()
            self.assertEqual(result['hostname'], 'test-host')


class TestPerformanceCollector(unittest.TestCase):
    """Test performance metrics collector."""
    
    def setUp(self):
        self.collector = PerformanceCollector(cache_duration=0.1)
    
    def test_collect_returns_dict(self):
        """Test that collect returns a dictionary."""
        result = self.collector.collect()
        self.assertIsInstance(result, dict)
    
    def test_performance_fields_present(self):
        """Test that performance fields are present."""
        result = self.collector.collect()
        expected_fields = ['cpu_percent', 'memory_percent', 'disk_percent']
        for field in expected_fields:
            self.assertIn(field, result)
    
    @patch('psutil.cpu_percent')
    def test_handles_psutil_errors(self, mock_cpu):
        """Test graceful handling of psutil errors."""
        mock_cpu.side_effect = Exception("Permission denied")
        result = self.collector.collect()
        self.assertIn('error', result)


class TestEnvironmentCollector(unittest.TestCase):
    """Test environment metadata collector."""
    
    def setUp(self):
        self.collector = EnvironmentCollector()
    
    def test_collect_returns_dict(self):
        """Test that collect returns a dictionary."""
        result = self.collector.collect()
        self.assertIsInstance(result, dict)
    
    def test_filters_sensitive_variables(self):
        """Test that sensitive environment variables are filtered out."""
        with patch.dict(os.environ, {
            'APP_NAME': 'test-app',
            'SECRET_KEY': 'secret-value',
            'PASSWORD': 'password-value'
        }):
            result = self.collector.collect()
            env_vars = result.get('environment_variables', {})
            self.assertIn('APP_NAME', env_vars)
            self.assertNotIn('SECRET_KEY', env_vars)
            self.assertNotIn('PASSWORD', env_vars)


if __name__ == '__main__':
    unittest.main()
EOF

# Create integration tests
cat > tests/test_integration.py << 'EOF'
"""
Integration tests for the complete enrichment pipeline.
"""

import unittest
import sys
import os
import json

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.pipeline import LogEnrichmentPipeline


class TestLogEnrichmentPipeline(unittest.TestCase):
    """Test the complete log enrichment pipeline."""
    
    def setUp(self):
        self.pipeline = LogEnrichmentPipeline()
    
    def test_enrich_simple_log(self):
        """Test enriching a simple log message."""
        raw_log = "INFO: User login successful"
        result = self.pipeline.enrich_log(raw_log, "test-app")
        
        # Verify basic structure
        self.assertIsInstance(result, dict)
        self.assertEqual(result['message'], raw_log)
        self.assertEqual(result['level'], 'INFO')
        self.assertEqual(result['source'], 'test-app')
        self.assertIn('hostname', result)
        self.assertIn('enriched_at', result)
    
    def test_enrich_error_log_includes_performance(self):
        """Test that ERROR logs include performance data."""
        raw_log = "ERROR: Database connection failed"
        result = self.pipeline.enrich_log(raw_log, "db-service")
        
        # Error logs should include performance metrics
        self.assertEqual(result['level'], 'ERROR')
        self.assertIn('cpu_percent', result)
        self.assertIn('memory_percent', result)
    
    def test_enrich_malformed_input(self):
        """Test handling of malformed input."""
        result = self.pipeline.enrich_log("", "test")
        
        # Should still return a valid structure
        self.assertIsInstance(result, dict)
        self.assertIn('timestamp', result)
    
    def test_pipeline_statistics(self):
        """Test pipeline statistics tracking."""
        # Process some logs
        self.pipeline.enrich_log("INFO: Test 1", "app1")
        self.pipeline.enrich_log("ERROR: Test 2", "app2")
        
        stats = self.pipeline.get_statistics()
        
        self.assertGreaterEqual(stats['processed_count'], 2)
        self.assertIn('success_rate', stats)
        self.assertIn('average_throughput', stats)
    
    def test_json_serialization(self):
        """Test that enriched logs can be serialized to JSON."""
        raw_log = "WARN: High memory usage detected"
        result = self.pipeline.enrich_log(raw_log, "monitor")
        
        # Should be JSON serializable
        json_str = json.dumps(result)
        parsed = json.loads(json_str)
        
        self.assertEqual(parsed['message'], raw_log)
        self.assertEqual(parsed['level'], 'WARN')


if __name__ == '__main__':
    unittest.main()
EOF

print_success "Configuration and tests created"

# ===================================================================
# STEP 7: Create Virtual Environment and Install Dependencies
# ===================================================================
print_step "Setting up Python virtual environment..."

# Create virtual environment
python3 -m venv venv

# Activate virtual environment and install dependencies
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

print_success "Virtual environment created and dependencies installed"

# ===================================================================
# STEP 8: Build and Test
# ===================================================================
print_step "Running tests and validation..."

# Run unit tests
echo "Running unit tests..."
python -m pytest tests/ -v --tb=short

# Test import functionality
echo "Testing imports..."
python -c "
import sys
sys.path.append('src')
from pipeline import LogEnrichmentPipeline
pipeline = LogEnrichmentPipeline()
result = pipeline.enrich_log('INFO: System startup complete', 'test')
print('✓ Pipeline import and basic functionality test passed')
print(f'✓ Enriched log contains {len(result)} fields')
"

print_success "Tests completed successfully"

# ===================================================================
# STEP 9: Create Docker Configuration
# ===================================================================
print_step "Creating Docker configuration..."

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.13-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY demo/ ./demo/
COPY config/ ./config/
COPY tests/ ./tests/

# Set environment variables
ENV PYTHONPATH=/app
ENV FLASK_APP=demo/demo_server.py
ENV ENVIRONMENT=docker

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/stats || exit 1

# Run the demo server
CMD ["python", "demo/demo_server.py"]
EOF

# Create log generator script
cat > demo/log_generator.py << 'EOF'
"""
Log generator script for testing the enrichment pipeline.
"""

import time
import requests
import random

logs = [
    'INFO: User authentication successful',
    'ERROR: Database connection timeout',
    'WARN: High CPU usage detected',
    'DEBUG: Cache miss for key user:12345',
    'CRITICAL: Disk space critically low'
]

while True:
    log = random.choice(logs)
    try:
        requests.post('http://log-enrichment:8080/api/enrich',
                     json={'log_message': log, 'source': 'auto-generator'})
        print(f'Sent: {log}')
    except:
        print('Failed to send log')
    time.sleep(5)
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  log-enrichment:
    build: .
    ports:
      - "8080:8080"
    environment:
      - ENVIRONMENT=docker
      - SERVICE_NAME=log-enrichment-pipeline
      - SERVICE_VERSION=1.0.0
      - REGION=local
    volumes:
      - ./config:/app/config:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/stats"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  # Optional: Add a simple log generator for testing
  log-generator:
    build: .
    command: python demo/log_generator.py
    depends_on:
      - log-enrichment
    restart: unless-stopped

volumes:
  config-data:
EOF

print_success "Docker configuration created"

# ===================================================================
# FINAL SETUP SUMMARY
# ===================================================================
print_step "Setup complete! Here's what was created:"

echo ""
echo "📁 Project Structure:"
echo "   ├── src/                     # Core implementation"
echo "   │   ├── collectors/          # Metadata collectors"
echo "   │   ├── enrichers/           # Enrichment logic"
echo "   │   ├── formatters/          # Output formatting"
echo "   │   └── pipeline.py          # Main pipeline"
echo "   ├── demo/                    # Web demo application"
echo "   ├── tests/                   # Test suite"
echo "   ├── config/                  # Configuration files"
echo "   └── Docker configuration     # Container setup"
echo ""

echo "🎯 Next Steps:"
echo "   1. Run 'python3 -m pytest tests/' for comprehensive testing"
echo "   2. Use 'docker-compose up' for containerized deployment"
echo "   3. Explore the code to understand enrichment patterns"
echo ""

echo "📊 Quick Test:"
echo "   curl -X POST http://localhost:8080/api/enrich \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"log_message\": \"ERROR: Test message\", \"source\": \"cli\"}'"
echo ""

echo "🐳 Docker Commands:"
echo "   Build: docker build -t log-enrichment ."
echo "   Run:   docker-compose up"
echo "   Test:  docker-compose run log-enrichment python -m pytest tests/"
echo ""

print_success "Log Enrichment Pipeline setup completed successfully!"

# ===================================================================
# VERIFICATION COMMANDS
# ===================================================================
echo ""
echo "🔍 Verification Commands:"
echo ""
echo "Test basic functionality:"
echo "python3 -c 'from src.pipeline import LogEnrichmentPipeline; pipeline = LogEnrichmentPipeline(); result = pipeline.enrich_log(\"ERROR: Critical system failure\", \"verification\"); print(\"Enrichment successful:\", \"hostname\" in result and \"cpu_percent\" in result); print(\"Fields added:\", len(result))'"
echo ""

echo "Run all tests:"
echo "python3 -m pytest tests/ -v"
echo ""

echo "Test API endpoint:"
echo "curl -X POST http://localhost:8080/api/enrich -H 'Content-Type: application/json' -d '{\"log_message\": \"INFO: Verification test\", \"source\": \"setup-script\"}'"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "🎉 Day 21 Implementation Complete!"
echo "You now have a fully functional log enrichment pipeline!"
echo "═══════════════════════════════════════════════════════════════"