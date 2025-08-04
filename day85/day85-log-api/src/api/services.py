import sqlite3
import json
import asyncio
import time
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, AsyncGenerator
from .models import LogEntry, LogQuery, LogStats
import os
import random

class LogService:
    def __init__(self, db_path: str = "logs.db"):
        self.db_path = db_path
        self.connection = None
    
    async def initialize(self):
        """Initialize database and create tables"""
        self.connection = sqlite3.connect(self.db_path, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        
        # Create logs table
        self.connection.execute("""
            CREATE TABLE IF NOT EXISTS logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                level TEXT NOT NULL,
                service TEXT NOT NULL,
                message TEXT NOT NULL,
                metadata TEXT,
                trace_id TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Create indexes for performance
        self.connection.execute("CREATE INDEX IF NOT EXISTS idx_timestamp ON logs(timestamp)")
        self.connection.execute("CREATE INDEX IF NOT EXISTS idx_level ON logs(level)")
        self.connection.execute("CREATE INDEX IF NOT EXISTS idx_service ON logs(service)")
        
        self.connection.commit()
        
        # Generate sample data if empty
        count = self.connection.execute("SELECT COUNT(*) FROM logs").fetchone()[0]
        if count == 0:
            await self._generate_sample_data()
    
    async def _generate_sample_data(self):
        """Generate sample log data for demonstration"""
        services = ["api-gateway", "user-service", "payment-service", "notification-service"]
        levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        messages = [
            "Request processed successfully",
            "User authentication completed",
            "Payment transaction initiated",
            "Database connection timeout", 
            "Memory usage exceeded threshold",
            "API rate limit exceeded",
            "Service dependency unavailable"
        ]
        
        # Generate 1000 sample logs
        for i in range(1000):
            timestamp = datetime.now() - timedelta(hours=random.randint(0, 24))
            level = random.choice(levels)
            service = random.choice(services)
            message = random.choice(messages)
            metadata = {"request_id": f"req_{i}", "user_id": f"user_{random.randint(1, 100)}"}
            
            self.connection.execute("""
                INSERT INTO logs (timestamp, level, service, message, metadata)
                VALUES (?, ?, ?, ?, ?)
            """, (timestamp.isoformat(), level, service, message, json.dumps(metadata)))
        
        self.connection.commit()
        print("📊 Generated 1000 sample log entries")
    
    async def get_logs(self, page: int, size: int, filters: Dict[str, Any]) -> Dict[str, Any]:
        """Retrieve logs with pagination and filtering"""
        offset = (page - 1) * size
        where_clauses = []
        params = []
        
        if filters.get("level"):
            where_clauses.append("level = ?")
            params.append(filters["level"])
        
        if filters.get("service"):
            where_clauses.append("service = ?")
            params.append(filters["service"])
        
        if filters.get("time_from"):
            where_clauses.append("timestamp >= ?")
            params.append(filters["time_from"].isoformat())
        
        if filters.get("time_to"):
            where_clauses.append("timestamp <= ?")
            params.append(filters["time_to"].isoformat())
        
        where_sql = "WHERE " + " AND ".join(where_clauses) if where_clauses else ""
        
        # Get total count
        count_query = f"SELECT COUNT(*) FROM logs {where_sql}"
        total = self.connection.execute(count_query, params).fetchone()[0]
        
        # Get logs
        query = f"""
            SELECT * FROM logs {where_sql}
            ORDER BY timestamp DESC
            LIMIT ? OFFSET ?
        """
        params.extend([size, offset])
        
        rows = self.connection.execute(query, params).fetchall()
        
        logs = []
        for row in rows:
            logs.append({
                "id": str(row["id"]),
                "timestamp": row["timestamp"],
                "level": row["level"],
                "service": row["service"],
                "message": row["message"],
                "metadata": json.loads(row["metadata"]) if row["metadata"] else {},
                "trace_id": row["trace_id"]
            })
        
        return {
            "logs": logs,
            "total": total,
            "has_next": total > offset + size
        }
    
    async def search_logs(self, query: LogQuery) -> Dict[str, Any]:
        """Advanced log search with complex queries"""
        start_time = time.time()
        
        where_clauses = ["message LIKE ?"]
        params = [f"%{query.query}%"]
        
        # Apply filters
        for key, value in query.filters.items():
            if key == "service":
                where_clauses.append("service = ?")
                params.append(value)
            elif key == "level":
                if isinstance(value, list):
                    where_clauses.append(f"level IN ({','.join(['?' for _ in value])})")
                    params.extend(value)
                else:
                    where_clauses.append("level = ?")
                    params.append(value)
        
        if query.time_from:
            where_clauses.append("timestamp >= ?")
            params.append(query.time_from.isoformat())
        
        if query.time_to:
            where_clauses.append("timestamp <= ?")
            params.append(query.time_to.isoformat())
        
        where_sql = "WHERE " + " AND ".join(where_clauses)
        
        # Get total count
        count_query = f"SELECT COUNT(*) FROM logs {where_sql}"
        total = self.connection.execute(count_query, params).fetchone()[0]
        
        # Get logs with pagination
        offset = (query.page - 1) * query.size
        search_query = f"""
            SELECT * FROM logs {where_sql}
            ORDER BY timestamp DESC
            LIMIT ? OFFSET ?
        """
        params.extend([query.size, offset])
        
        rows = self.connection.execute(search_query, params).fetchall()
        
        logs = []
        for row in rows:
            logs.append({
                "id": str(row["id"]),
                "timestamp": row["timestamp"],
                "level": row["level"],
                "service": row["service"],
                "message": row["message"],
                "metadata": json.loads(row["metadata"]) if row["metadata"] else {}
            })
        
        query_time = int((time.time() - start_time) * 1000)
        
        return {
            "logs": logs,
            "total": total,
            "query_time": query_time,
            "aggregations": self._calculate_aggregations(logs) if query.aggregations else {}
        }
    
    async def stream_logs(self, level: Optional[str], service: Optional[str]) -> AsyncGenerator[Dict, None]:
        """Stream real-time logs"""
        # Simulate real-time log streaming
        services = ["api-gateway", "user-service", "payment-service"]
        levels = ["INFO", "WARNING", "ERROR"]
        messages = ["New request received", "Processing completed", "Error occurred"]
        
        while True:
            # Generate a new log entry
            log_entry = {
                "id": str(int(time.time() * 1000)),
                "timestamp": datetime.now().isoformat(),
                "level": random.choice(levels),
                "service": random.choice(services),
                "message": random.choice(messages),
                "metadata": {"stream": True}
            }
            
            # Apply filters
            if level and log_entry["level"] != level:
                await asyncio.sleep(1)
                continue
            
            if service and log_entry["service"] != service:
                await asyncio.sleep(1)
                continue
            
            yield log_entry
            await asyncio.sleep(2)  # New log every 2 seconds
    
    async def get_stats(self, time_range: str) -> Dict[str, Any]:
        """Get log statistics"""
        hours = {"1h": 1, "24h": 24, "7d": 168, "30d": 720}[time_range]
        since = datetime.now() - timedelta(hours=hours)
        
        # Total logs
        total_query = "SELECT COUNT(*) FROM logs WHERE timestamp >= ?"
        total = self.connection.execute(total_query, [since.isoformat()]).fetchone()[0]
        
        # Logs by level
        level_query = """
            SELECT level, COUNT(*) as count FROM logs 
            WHERE timestamp >= ? 
            GROUP BY level
        """
        level_rows = self.connection.execute(level_query, [since.isoformat()]).fetchall()
        logs_by_level = {row["level"]: row["count"] for row in level_rows}
        
        # Logs by service
        service_query = """
            SELECT service, COUNT(*) as count FROM logs 
            WHERE timestamp >= ? 
            GROUP BY service
            ORDER BY count DESC
        """
        service_rows = self.connection.execute(service_query, [since.isoformat()]).fetchall()
        logs_by_service = {row["service"]: row["count"] for row in service_rows}
        
        # Error rate
        error_count = logs_by_level.get("ERROR", 0) + logs_by_level.get("CRITICAL", 0)
        error_rate = (error_count / total * 100) if total > 0 else 0
        
        return {
            "total_logs": total,
            "logs_by_level": logs_by_level,
            "logs_by_service": logs_by_service,
            "error_rate": round(error_rate, 2),
            "avg_logs_per_hour": round(total / hours, 2),
            "time_range": time_range
        }
    
    def _calculate_aggregations(self, logs: List[Dict]) -> Dict[str, Any]:
        """Calculate aggregations on log results"""
        if not logs:
            return {}
        
        levels = {}
        services = {}
        
        for log in logs:
            levels[log["level"]] = levels.get(log["level"], 0) + 1
            services[log["service"]] = services.get(log["service"], 0) + 1
        
        return {
            "count_by_level": levels,
            "count_by_service": services
        }
    
    async def health_check(self) -> bool:
        """Check service health"""
        try:
            self.connection.execute("SELECT 1").fetchone()
            return True
        except:
            return False

class AuthService:
    def __init__(self):
        self.users = {
            "developer": {"password": "dev123", "role": "developer", "rate_limit": 1000},
            "operator": {"password": "ops123", "role": "operations", "rate_limit": 5000},
            "security": {"password": "sec123", "role": "security", "rate_limit": 10000}
        }
    
    async def initialize(self):
        """Initialize auth service"""
        print("🔐 Auth service initialized")
    
    async def authenticate(self, username: str, password: str) -> str:
        """Authenticate user and return token"""
        user = self.users.get(username)
        if user and user["password"] == password:
            # Simple token generation (in production, use proper JWT)
            token = f"token_{username}_{int(time.time())}"
            return token
        raise ValueError("Invalid credentials")
    
    async def health_check(self) -> bool:
        """Check auth service health"""
        return True
