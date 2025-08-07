import asyncio
import json
import time
from typing import Dict, List, Optional, AsyncGenerator, Union
import requests
import websockets
from .config import Config
from .models import LogEntry, QueryResult, StreamConfig
from .exceptions import LogPlatformError, ConnectionError, AuthenticationError

class LogPlatformClient:
    """Main client for interacting with the log platform."""
    
    def __init__(self, config: Optional[Config] = None):
        self.config = config or Config()
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {self.config.api_key}',
            'Content-Type': 'application/json',
            'User-Agent': f'logplatform-python-sdk/1.0.0'
        })
        self._websocket = None
        self._connection_pool = {}
        
    def submit_log(self, log_entry: LogEntry) -> Dict:
        """Submit a single log entry."""
        try:
            response = self.session.post(
                f"{self.config.base_url}/api/v1/logs",
                json=json.loads(log_entry.model_dump_json()),
                timeout=self.config.timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            raise ConnectionError(f"Failed to submit log: {e}")
    
    def submit_logs_batch(self, log_entries: List[LogEntry]) -> Dict:
        """Submit multiple log entries in a batch."""
        try:
            payload = [json.loads(entry.model_dump_json()) for entry in log_entries]
            response = self.session.post(
                f"{self.config.base_url}/api/v1/logs/batch",
                json={"logs": payload},
                timeout=self.config.timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            raise ConnectionError(f"Failed to submit batch: {e}")
    
    def query_logs(self, query: str, limit: int = 100) -> QueryResult:
        """Query logs with the specified criteria."""
        try:
            response = self.session.get(
                f"{self.config.base_url}/api/v1/logs/query",
                params={"q": query, "limit": limit},
                timeout=self.config.timeout
            )
            response.raise_for_status()
            data = response.json()
            return QueryResult(
                logs=[LogEntry(**log) for log in data.get("logs", [])],
                total_count=data.get("total_count", 0),
                query_time_ms=data.get("query_time_ms", 0)
            )
        except requests.RequestException as e:
            raise ConnectionError(f"Failed to query logs: {e}")
    
    async def stream_logs(self, stream_config: StreamConfig) -> AsyncGenerator[LogEntry, None]:
        """Stream logs in real-time using WebSocket connection."""
        uri = f"{self.config.websocket_url}/api/v1/logs/stream"
        headers = {"Authorization": f"Bearer {self.config.api_key}"}
        
        try:
            async with websockets.connect(uri, additional_headers=headers) as websocket:
                await websocket.send(stream_config.model_dump_json())
                
                async for message in websocket:
                    try:
                        data = json.loads(message)
                        if data.get("type") == "log":
                            yield LogEntry(**data.get("payload", {}))
                        elif data.get("type") == "error":
                            raise LogPlatformError(data.get("message", "Stream error"))
                    except json.JSONDecodeError:
                        continue
        except Exception as e:
            raise ConnectionError(f"WebSocket connection failed: {e}")
    
    def health_check(self) -> Dict:
        """Check platform health status."""
        try:
            response = self.session.get(
                f"{self.config.base_url}/api/v1/health",
                timeout=5
            )
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            raise ConnectionError(f"Health check failed: {e}")
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.session.close()
