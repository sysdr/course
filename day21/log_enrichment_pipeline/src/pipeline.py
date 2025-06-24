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
