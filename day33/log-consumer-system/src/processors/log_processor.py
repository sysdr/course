import json
import time
from typing import Dict, Any
from dataclasses import asdict
from src.consumers.log_consumer import LogMessage
import structlog

logger = structlog.get_logger()

class LogProcessor:
    def __init__(self):
        self.metrics = {
            "total_processed": 0,
            "error_logs": 0,
            "warn_logs": 0,
            "info_logs": 0,
            "response_times": [],
            "endpoints": {}
        }
    
    def process(self, log_message: LogMessage) -> bool:
        """Process a log message and extract metrics"""
        try:
            self.metrics["total_processed"] += 1
            
            # Count by log level
            level = log_message.level.lower()
            if level == "error":
                self.metrics["error_logs"] += 1
            elif level == "warn":
                self.metrics["warn_logs"] += 1
            elif level == "info":
                self.metrics["info_logs"] += 1
            
            # Extract metrics from web server logs
            if self._is_web_server_log(log_message):
                self._process_web_log(log_message)
            
            # Store processed log (in production, this would go to database)
            self._store_processed_log(log_message)
            
            logger.info(f"Processed log from {log_message.source}: {log_message.level}")
            return True
            
        except Exception as e:
            logger.error(f"Error processing log: {e}")
            return False
    
    def _is_web_server_log(self, log_message: LogMessage) -> bool:
        """Check if this is a web server access log"""
        return (log_message.source == "web-server" and 
                log_message.metadata and 
                "response_time" in log_message.metadata)
    
    def _process_web_log(self, log_message: LogMessage):
        """Extract metrics from web server logs"""
        metadata = log_message.metadata
        
        # Track response times
        if "response_time" in metadata:
            response_time = float(metadata["response_time"])
            self.metrics["response_times"].append(response_time)
        
        # Track endpoints
        if "endpoint" in metadata:
            endpoint = metadata["endpoint"]
            if endpoint not in self.metrics["endpoints"]:
                self.metrics["endpoints"][endpoint] = {
                    "count": 0,
                    "total_response_time": 0,
                    "errors": 0
                }
            
            self.metrics["endpoints"][endpoint]["count"] += 1
            if "response_time" in metadata:
                self.metrics["endpoints"][endpoint]["total_response_time"] += float(metadata["response_time"])
            
            if "status_code" in metadata and int(metadata["status_code"]) >= 400:
                self.metrics["endpoints"][endpoint]["errors"] += 1
    
    def _store_processed_log(self, log_message: LogMessage):
        """Store processed log (mock implementation)"""
        # In production, this would store to database
        log_data = asdict(log_message)
        log_data["processed_at"] = time.time()
        
        # For demo, just log to file
        with open("logs/processed_logs.jsonl", "a") as f:
            f.write(json.dumps(log_data) + "\n")
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get processing metrics"""
        metrics = self.metrics.copy()
        
        # Calculate average response times per endpoint
        for endpoint, data in metrics["endpoints"].items():
            if data["count"] > 0:
                data["avg_response_time"] = data["total_response_time"] / data["count"]
                data["error_rate"] = data["errors"] / data["count"]
        
        # Calculate overall average response time
        if metrics["response_times"]:
            metrics["avg_response_time"] = sum(metrics["response_times"]) / len(metrics["response_times"])
        
        return metrics
