import aiohttp
import asyncio
import json
import structlog
from typing import Dict, Any, Optional, List
from datetime import datetime

logger = structlog.get_logger()

class NetworkClient:
    def __init__(self, timeout: int = 30):
        self.timeout = aiohttp.ClientTimeout(total=timeout)
        self.session: Optional[aiohttp.ClientSession] = None
    
    async def start(self):
        """Initialize the HTTP session"""
        self.session = aiohttp.ClientSession(timeout=self.timeout)
    
    async def stop(self):
        """Close the HTTP session"""
        if self.session:
            await self.session.close()
    
    async def post_json(self, url: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Send POST request with JSON data"""
        if not self.session:
            await self.start()
            
        try:
            async with self.session.post(url, json=data) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    error_text = await response.text()
                    raise Exception(f"HTTP {response.status}: {error_text}")
        except asyncio.TimeoutError:
            raise Exception(f"Timeout connecting to {url}")
        except Exception as e:
            logger.error("Network request failed", url=url, error=str(e))
            raise

    async def get_json(self, url: str) -> Dict[str, Any]:
        """Send GET request and return JSON response"""
        if not self.session:
            await self.start()
            
        try:
            async with self.session.get(url) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    error_text = await response.text()
                    raise Exception(f"HTTP {response.status}: {error_text}")
        except asyncio.TimeoutError:
            raise Exception(f"Timeout connecting to {url}")
        except Exception as e:
            logger.error("Network request failed", url=url, error=str(e))
            raise

class PartitionInfo:
    def __init__(self, partition_id: str, host: str, port: int, 
                 time_ranges: List[Dict[str, Any]], status: str = "healthy"):
        self.partition_id = partition_id
        self.host = host
        self.port = port
        self.time_ranges = time_ranges
        self.status = status
        self.last_health_check = datetime.now()
    
    @property
    def base_url(self) -> str:
        return f"http://{self.host}:{self.port}"
    
    def covers_time_range(self, start: datetime, end: datetime) -> bool:
        """Check if this partition covers the given time range"""
        for time_range in self.time_ranges:
            range_start = datetime.fromisoformat(time_range["start"])
            range_end = datetime.fromisoformat(time_range["end"])
            
            # Check for overlap
            if start <= range_end and end >= range_start:
                return True
        return False
    
    def is_healthy(self) -> bool:
        return self.status == "healthy"
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "partition_id": self.partition_id,
            "host": self.host,
            "port": self.port,
            "time_ranges": self.time_ranges,
            "status": self.status,
            "last_health_check": self.last_health_check.isoformat()
        }
