import asyncio
import json
import random
from datetime import datetime, timezone
from typing import AsyncGenerator, List
from ..models.log_entry import LogEntry, LogLevel
import structlog

logger = structlog.get_logger()

class LogStreamer:
    """Service for streaming log entries in real-time"""
    
    def __init__(self):
        self.is_running = False
        self.available_streams = {
            "application": "Application Logs",
            "system": "System Logs", 
            "security": "Security Logs",
            "database": "Database Logs",
            "api": "API Logs"
        }
        
    async def start(self):
        """Start the log streaming service"""
        self.is_running = True
        logger.info("Log streamer started", streams=list(self.available_streams.keys()))
        
    async def stop(self):
        """Stop the log streaming service"""
        self.is_running = False
        logger.info("Log streamer stopped")
        
    async def get_available_streams(self) -> List[dict]:
        """Get list of available streams"""
        return [
            {"id": stream_id, "name": name, "active": self.is_running}
            for stream_id, name in self.available_streams.items()
        ]
        
    async def stream_logs(self, stream_id: str) -> AsyncGenerator[LogEntry, None]:
        """Stream logs for a specific stream"""
        if stream_id not in self.available_streams:
            raise ValueError(f"Unknown stream: {stream_id}")
            
        logger.info("Starting log stream", stream_id=stream_id)
        
        # Create a new generator for each connection
        generator = self._create_log_generator(stream_id)
        async for log_entry in generator:
            if not self.is_running:
                break
            yield log_entry
            
    def _create_log_generator(self, stream_id: str) -> AsyncGenerator[LogEntry, None]:
        """Create async generator for log entries"""
        async def generator():
            counter = 0
            while self.is_running:
                await asyncio.sleep(random.uniform(0.1, 2.0))  # Variable delay
                counter += 1
                
                # Generate realistic log entry based on stream_id
                log_entry = self._generate_log_entry(stream_id, counter)
                yield log_entry
                
        return generator()
        
    def _generate_log_entry(self, stream_id: str, counter: int) -> LogEntry:
        """Generate a realistic log entry for the stream"""
        timestamp = datetime.now(timezone.utc)
        
        if stream_id == "application":
            messages = [
                "User authentication successful",
                "Processing payment transaction",
                "Cache miss for user profile",
                "Email notification sent",
                "File upload completed",
                "Session timeout warning",
                "API rate limit exceeded",
                "Database connection pool exhausted"
            ]
            levels = [LogLevel.INFO, LogLevel.INFO, LogLevel.WARN, LogLevel.INFO, 
                     LogLevel.INFO, LogLevel.WARN, LogLevel.ERROR, LogLevel.ERROR]
            
        elif stream_id == "system":
            messages = [
                "CPU usage at 78%",
                "Memory cleanup completed",
                "Disk space warning: 85% full",
                "Network latency spike detected",
                "Service restart initiated",
                "Configuration reload successful",
                "Process killed due to memory limit",
                "System backup completed"
            ]
            levels = [LogLevel.INFO, LogLevel.INFO, LogLevel.WARN, LogLevel.WARN,
                     LogLevel.INFO, LogLevel.INFO, LogLevel.ERROR, LogLevel.INFO]
                     
        elif stream_id == "security":
            messages = [
                "Login attempt from new IP",
                "JWT token validated",
                "Failed authentication attempt",
                "Suspicious API usage detected",
                "User account locked",
                "SSL certificate renewal",
                "Potential SQL injection blocked",
                "Malicious file upload blocked"
            ]
            levels = [LogLevel.INFO, LogLevel.INFO, LogLevel.WARN, LogLevel.WARN,
                     LogLevel.WARN, LogLevel.INFO, LogLevel.ERROR, LogLevel.ERROR]
                     
        elif stream_id == "database":
            messages = [
                "Query executed successfully",
                "Connection pool status: healthy",
                "Slow query detected: 2.5s",
                "Index optimization completed",
                "Transaction deadlock resolved",
                "Database backup started",
                "Connection timeout error",
                "Replication lag detected"
            ]
            levels = [LogLevel.INFO, LogLevel.INFO, LogLevel.WARN, LogLevel.INFO,
                     LogLevel.WARN, LogLevel.INFO, LogLevel.ERROR, LogLevel.WARN]
                     
        else:  # api
            messages = [
                "GET /api/users/123 - 200 OK",
                "POST /api/orders - 201 Created",
                "GET /api/products - 404 Not Found",
                "PUT /api/users/456 - 422 Validation Error",
                "DELETE /api/sessions - 500 Internal Error",
                "GET /api/health - 200 OK",
                "POST /api/login - 429 Rate Limited",
                "GET /api/metrics - 503 Service Unavailable"
            ]
            levels = [LogLevel.INFO, LogLevel.INFO, LogLevel.WARN, LogLevel.WARN,
                     LogLevel.ERROR, LogLevel.INFO, LogLevel.WARN, LogLevel.ERROR]
                     
        # Select random message and corresponding level
        idx = random.randint(0, len(messages) - 1)
        message = messages[idx]
        level = levels[idx]
        
        return LogEntry(
            id=f"{stream_id}-{counter}",
            timestamp=timestamp,
            level=level,
            message=message,
            source=stream_id,
            stream_id=stream_id,
            metadata={
                "thread_id": f"thread-{random.randint(1, 10)}",
                "request_id": f"req-{random.randint(1000, 9999)}",
                "user_id": f"user-{random.randint(100, 999)}" if stream_id in ["application", "websocket", "api"] else None
            }
        )
