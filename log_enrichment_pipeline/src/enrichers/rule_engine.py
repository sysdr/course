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
