import asyncio
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import structlog
from datetime import datetime
from typing import Dict, Any, Optional

from coordinator.query_coordinator import QueryCoordinator
from coordinator.partition_map import PartitionMap
from common.query_types import Query, TimeRange, QueryFilter

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

app = FastAPI(title="Distributed Log Query System", version="1.0.0")

# Global components
partition_map: Optional[PartitionMap] = None
query_coordinator: Optional[QueryCoordinator] = None

@app.on_event("startup")
async def startup_event():
    """Initialize the query system on startup"""
    global partition_map, query_coordinator
    
    logger.info("Starting distributed log query system")
    
    # Initialize partition map
    partition_map = PartitionMap()
    await partition_map.start()
    
    # Initialize query coordinator
    query_coordinator = QueryCoordinator(partition_map)
    await query_coordinator.start()
    
    logger.info("System startup complete")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    global partition_map, query_coordinator
    
    logger.info("Shutting down distributed log query system")
    
    if query_coordinator:
        await query_coordinator.stop()
    
    if partition_map:
        await partition_map.stop()
    
    logger.info("System shutdown complete")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "distributed-log-query-coordinator"
    }

@app.post("/query")
async def execute_query(query_data: Dict[str, Any]):
    """Execute a distributed query"""
    if not query_coordinator:
        raise HTTPException(status_code=503, detail="Query coordinator not initialized")
    
    try:
        # Parse query data
        query = parse_query_data(query_data)
        
        # Execute query
        result = await query_coordinator.execute_query(query)
        
        return {
            "query_id": result.query_id,
            "total_results": result.total_results,
            "results": result.results,
            "partitions_queried": result.partitions_queried,
            "partitions_successful": result.partitions_successful,
            "total_execution_time_ms": result.total_execution_time_ms,
            "errors": result.errors
        }
        
    except Exception as e:
        logger.error("Query execution failed", error=str(e))
        raise HTTPException(status_code=500, detail=f"Query failed: {str(e)}")

@app.get("/stats")
async def get_stats():
    """Get system statistics"""
    if not partition_map or not query_coordinator:
        raise HTTPException(status_code=503, detail="System not initialized")
    
    partition_stats = partition_map.get_partition_stats()
    cache_stats = query_coordinator.get_cache_stats()
    
    return {
        "partitions": partition_stats,
        "cache": cache_stats,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/partitions")
async def get_partitions():
    """Get information about all partitions"""
    if not partition_map:
        raise HTTPException(status_code=503, detail="Partition map not initialized")
    
    partitions = partition_map.get_healthy_partitions()
    
    return {
        "partitions": [p.to_dict() for p in partitions],
        "total_count": len(partitions)
    }

def parse_query_data(query_data: Dict[str, Any]) -> Query:
    """Parse query data from request"""
    query = Query()
    
    # Parse time range
    if "time_range" in query_data and query_data["time_range"]:
        time_range_data = query_data["time_range"]
        if time_range_data.get("start") and time_range_data.get("end"):
            query.time_range = TimeRange(
                start=datetime.fromisoformat(time_range_data["start"].replace('Z', '+00:00')),
                end=datetime.fromisoformat(time_range_data["end"].replace('Z', '+00:00'))
            )
    
    # Parse filters
    if "filters" in query_data:
        for filter_data in query_data["filters"]:
            query_filter = QueryFilter(
                field=filter_data["field"],
                operator=filter_data["operator"],
                value=filter_data["value"]
            )
            query.filters.append(query_filter)
    
    # Parse other fields
    if "sort_field" in query_data:
        query.sort_field = query_data["sort_field"]
    
    if "sort_order" in query_data:
        query.sort_order = query_data["sort_order"]
    
    if "limit" in query_data:
        query.limit = query_data["limit"]
    
    return query

# Mount static files for web interface
app.mount("/static", StaticFiles(directory="web"), name="static")

@app.get("/", response_class=HTMLResponse)
async def get_web_interface():
    """Serve the web interface"""
    with open("web/index.html", "r") as f:
        return HTMLResponse(content=f.read())

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        log_level="info"
    )
