import random
import time
from datetime import datetime, timedelta
from typing import List
from models.log_entry import LogEntry, LogLevel

class LogGenerator:
    """Generate realistic log data for testing"""
    
    SERVICES = ["web-api", "user-service", "payment-service", "database", "security"]
    COMPONENTS = ["controller", "service", "repository", "middleware", "auth"]
    
    LOG_MESSAGES = {
        LogLevel.INFO: [
            "User logged in successfully",
            "Request processed successfully", 
            "Database connection established",
            "Cache hit for user data",
            "Service started successfully"
        ],
        LogLevel.WARN: [
            "High memory usage detected",
            "Slow database query detected",
            "Rate limit approaching",
            "Cache miss for frequent request",
            "Deprecated API endpoint accessed"
        ],
        LogLevel.ERROR: [
            "Database connection failed",
            "Authentication failed",
            "Payment processing error",
            "External service timeout",
            "Invalid request format"
        ]
    }
    
    def __init__(self):
        self.user_ids = [f"user_{i}" for i in range(1, 1001)]
        self.session_ids = [f"session_{i}" for i in range(1, 501)]
        
    def generate_log(self, 
                    level: str = None, 
                    service: str = None,
                    timestamp: datetime = None) -> LogEntry:
        """Generate a single log entry"""
        
        level = level or random.choice([
            LogLevel.INFO, LogLevel.INFO, LogLevel.INFO,  # Higher probability
            LogLevel.WARN, LogLevel.ERROR
        ])
        
        service = service or random.choice(self.SERVICES)
        component = random.choice(self.COMPONENTS)
        message = random.choice(self.LOG_MESSAGES[level])
        
        # Add realistic metadata
        metadata = {
            "ip_address": f"192.168.1.{random.randint(1, 255)}",
            "user_agent": "Mozilla/5.0 (compatible; LogGenerator/1.0)",
            "endpoint": f"/api/v1/{component}/{random.randint(1, 100)}",
            "response_time_ms": random.randint(10, 2000),
            "request_id": f"req_{random.randint(10000, 99999)}"
        }
        
        # Add error-specific metadata
        if level == LogLevel.ERROR:
            metadata.update({
                "error_code": f"ERR_{random.randint(1000, 9999)}",
                "stack_trace": f"at {component}.{random.choice(['process', 'handle', 'execute'])}(line:{random.randint(1, 500)})"
            })
            
        return LogEntry(
            timestamp=timestamp or datetime.now(),
            level=level,
            message=message,
            service=service,
            component=component,
            user_id=random.choice(self.user_ids) if random.random() > 0.3 else None,
            session_id=random.choice(self.session_ids) if random.random() > 0.5 else None,
            metadata=metadata
        )
        
    def generate_batch(self, count: int, timespan_minutes: int = 60) -> List[LogEntry]:
        """Generate a batch of log entries over a time span"""
        logs = []
        start_time = datetime.now() - timedelta(minutes=timespan_minutes)
        
        for i in range(count):
            # Distribute logs evenly over timespan
            timestamp = start_time + timedelta(
                minutes=(timespan_minutes * i / count)
            )
            logs.append(self.generate_log(timestamp=timestamp))
            
        return logs
        
    def generate_error_burst(self, count: int = 50) -> List[LogEntry]:
        """Generate a burst of error logs (simulating an incident)"""
        return [
            self.generate_log(level=LogLevel.ERROR, service="payment-service")
            for _ in range(count)
        ]
        
    def generate_high_volume_stream(self, duration_seconds: int = 60, rate_per_second: int = 100):
        """Generate high-volume log stream for performance testing"""
        start_time = time.time()
        logs_generated = 0
        
        while time.time() - start_time < duration_seconds:
            batch_start = time.time()
            
            # Generate logs for this second
            for _ in range(rate_per_second):
                yield self.generate_log()
                logs_generated += 1
                
            # Sleep to maintain rate
            elapsed = time.time() - batch_start
            if elapsed < 1.0:
                time.sleep(1.0 - elapsed)
                
        print(f"Generated {logs_generated} logs in {duration_seconds} seconds")
