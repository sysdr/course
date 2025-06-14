import time
import random
import structlog
from typing import Dict, Any

logger = structlog.get_logger()

class LogProcessor:
    def __init__(self, failure_rate: float = 0.2, timeout_rate: float = 0.1):
        self.failure_rate = failure_rate
        self.timeout_rate = timeout_rate
        self.processed_logs = []
    
    def process_log_entry(self, log_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Simulate log processing with random failures for testing
        """
        delivery_tag = log_data.get('_delivery_tag', 'unknown')
        
        logger.info("Processing log entry", 
                   delivery_tag=delivery_tag,
                   log_type=log_data.get('type', 'unknown'))
        
        # Simulate processing time
        time.sleep(random.uniform(0.1, 0.5))
        
        # Simulate random failures for testing
        if random.random() < self.timeout_rate:
            raise TimeoutError("Database connection timeout")
        
        if random.random() < self.failure_rate:
            if random.random() < 0.7:  # 70% retryable errors
                raise ConnectionError("Temporary service unavailable")
            else:  # 30% fatal errors
                raise ValueError("Invalid log format - cannot process")
        
        # Successful processing
        processed_entry = {
            'original_log': log_data,
            'processed_at': time.time(),
            'status': 'success',
            'processing_duration': random.uniform(0.1, 0.5)
        }
        
        self.processed_logs.append(processed_entry)
        
        logger.info("Log entry processed successfully", 
                   delivery_tag=delivery_tag,
                   total_processed=len(self.processed_logs))
        
        return processed_entry
    
    def get_stats(self) -> Dict[str, Any]:
        """Get processing statistics"""
        return {
            'total_processed': len(self.processed_logs),
            'configured_failure_rate': self.failure_rate,
            'configured_timeout_rate': self.timeout_rate
        }
