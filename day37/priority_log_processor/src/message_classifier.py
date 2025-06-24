import re
from typing import Dict, Any
from .priority_queue import Priority

class MessageClassifier:
    def __init__(self):
        # Critical patterns - system failures, security, payments
        self.critical_patterns = [
            r'(?i)(payment.*failed|transaction.*error|security.*breach)',
            r'(?i)(system.*down|service.*unavailable|critical.*error)',
            r'(?i)(authentication.*failed|unauthorized.*access)',
            r'(?i)(database.*connection.*lost|connection.*timeout)'
        ]
        
        # High priority patterns - performance issues, warnings
        self.high_patterns = [
            r'(?i)(high.*latency|slow.*response|performance.*degraded)',
            r'(?i)(warning|warn|alert)',
            r'(?i)(memory.*usage.*high|cpu.*usage.*high)',
            r'(?i)(queue.*full|buffer.*overflow)'
        ]
        
        # Medium priority patterns - business logic errors
        self.medium_patterns = [
            r'(?i)(user.*error|validation.*failed|business.*logic)',
            r'(?i)(info|information)',
            r'(?i)(user.*action|request.*processed)'
        ]
        
        # Everything else is LOW priority
        
    def classify(self, message_content: Dict[str, Any]) -> Priority:
        """Classify message based on content patterns"""
        # Convert message to string for pattern matching
        text = str(message_content)
        
        # Check critical patterns first
        for pattern in self.critical_patterns:
            if re.search(pattern, text):
                return Priority.CRITICAL
        
        # Check high priority patterns
        for pattern in self.high_patterns:
            if re.search(pattern, text):
                return Priority.HIGH
        
        # Check medium priority patterns
        for pattern in self.medium_patterns:
            if re.search(pattern, text):
                return Priority.MEDIUM
        
        # Default to low priority
        return Priority.LOW
    
    def classify_by_source(self, source: str) -> Priority:
        """Classify based on message source/service"""
        critical_services = ['payment', 'auth', 'security', 'database']
        high_services = ['api-gateway', 'load-balancer', 'cache']
        medium_services = ['user-service', 'order-service']
        
        source_lower = source.lower()
        
        if any(service in source_lower for service in critical_services):
            return Priority.CRITICAL
        elif any(service in source_lower for service in high_services):
            return Priority.HIGH
        elif any(service in source_lower for service in medium_services):
            return Priority.MEDIUM
        else:
            return Priority.LOW
