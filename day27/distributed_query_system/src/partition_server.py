import asyncio
import uvicorn
from fastapi import FastAPI, HTTPException
import structlog
from datetime import datetime
from typing import Dict, Any
import sys
import os

from .executor.partition_executor import PartitionExecutor
from .common.query_types import Query, TimeRange, QueryFilter

logger = structlog.get_logger()

class PartitionServer:
    def __init__(self, partition_id: str, port: int, data_dir: str = None):
        self.partition_id = partition_id
        self.port = port
        self.data_dir = data_dir or f"data/partition_{partition_id}"
        self.app = FastAPI(title=f"Partition Server {partition_id}")
        self.executor: PartitionExecutor = None
        
        self._setup_routes()
    
    def _setup_routes(self):
        @self.app.on_event("startup")
        async def startup():
            os.makedirs(self.data_dir, exist_ok=True)
            self.executor = PartitionExecutor(self.partition_id, self.data_dir)
            await self.executor.start()
            logger.info("Partition server started", 
                       partition_id=self.partition_id,
                       port=self.port)
        
        @self.app.on_event("shutdown")
        async def shutdown():
            if self.executor:
                await self.executor.stop()
        
        @self.app.get("/health")
        async def health():
            if self.executor:
                return await self.executor.get_health_status()
            return {"status": "starting"}
        
        @self.app.post("/query")
        async def query(query_data: Dict[str, Any]):
            if not self.executor:
                raise HTTPException(status_code=503, detail="Executor not ready")
            
            try:
                query = self._parse_query(query_data)
                result = await self.executor.execute_query(query)
                return result
            except Exception as e:
                logger.error("Query failed", partition_id=self.partition_id, error=str(e))
                raise HTTPException(status_code=500, detail=str(e))
        
        @self.app.get("/time-ranges")
        async def time_ranges():
            if not self.executor:
                raise HTTPException(status_code=503, detail="Executor not ready")
            
            return await self.executor.get_time_ranges()
    
    def _parse_query(self, query_data: Dict[str, Any]) -> Query:
        """Parse query data into Query object"""
        query = Query()
        
        if "time_range" in query_data and query_data["time_range"]:
            time_range_data = query_data["time_range"]
            if time_range_data.get("start") and time_range_data.get("end"):
                query.time_range = TimeRange(
                    start=datetime.fromisoformat(time_range_data["start"].replace('Z', '+00:00')),
                    end=datetime.fromisoformat(time_range_data["end"].replace('Z', '+00:00'))
                )
        
        if "filters" in query_data:
            for filter_data in query_data["filters"]:
                query_filter = QueryFilter(
                    field=filter_data["field"],
                    operator=filter_data["operator"],
                    value=filter_data["value"]
                )
                query.filters.append(query_filter)
        
        query.sort_field = query_data.get("sort_field", "timestamp")
        query.sort_order = query_data.get("sort_order", "desc")
        query.limit = query_data.get("limit")
        
        return query
    
    def run(self):
        uvicorn.run(
            self.app,
            host="0.0.0.0",
            port=self.port,
            log_level="info"
        )

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python partition_server.py <partition_id> <port>")
        sys.exit(1)
    
    partition_id = sys.argv[1]
    port = int(sys.argv[2])
    
    server = PartitionServer(partition_id, port)
    server.run()
