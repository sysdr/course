from fastapi import FastAPI, HTTPException, BackgroundTasks, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from typing import List, Dict, Any, Optional
import asyncio
import time
import json
import logging
from datetime import datetime, timezone

from ..batch.batch_processor import BatchProcessor
from ..models.log_models import LogEntry, BatchRequest, BatchResponse, BatchStats
from ..monitoring.metrics import MetricsCollector
from ..utils.database import get_db_session

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Distributed Log Processing - Batch API",
    description="High-performance batch operations for log processing",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files and templates
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# Initialize components
batch_processor = BatchProcessor()
metrics = MetricsCollector()

@app.on_event("startup")
async def startup_event():
    """Initialize system on startup"""
    logger.info("🚀 Starting Batch API Operations System")
    await batch_processor.initialize()
    metrics.start_collection()

@app.get("/", response_class=HTMLResponse)
async def dashboard(request):
    """Main dashboard page"""
    stats = await metrics.get_current_stats()
    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "stats": stats
    })

@app.post("/api/v1/logs/batch", response_model=BatchResponse)
async def batch_insert_logs(
    batch_request: BatchRequest,
    background_tasks: BackgroundTasks,
    db_session = Depends(get_db_session)
):
    """Insert multiple log entries in a single batch operation"""
    start_time = time.time()
    
    try:
        logger.info(f"📦 Processing batch of {len(batch_request.logs)} log entries")
        
        # Validate batch size
        if len(batch_request.logs) > 10000:
            raise HTTPException(
                status_code=400,
                detail="Batch size exceeds maximum limit of 10000 entries"
            )
        
        # Process batch
        result = await batch_processor.process_batch_insert(
            batch_request.logs,
            db_session,
            chunk_size=batch_request.chunk_size or 1000
        )
        
        # Record metrics
        processing_time = time.time() - start_time
        background_tasks.add_task(
            metrics.record_batch_operation,
            "insert", len(batch_request.logs), processing_time, result.success_count
        )
        
        return BatchResponse(
            success=result.success_count == len(batch_request.logs),
            total_processed=len(batch_request.logs),
            success_count=result.success_count,
            error_count=result.error_count,
            errors=result.errors,
            processing_time=processing_time,
            batch_id=result.batch_id
        )
        
    except Exception as e:
        logger.error(f"❌ Batch insert failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/logs/batch/query", response_model=Dict[str, Any])
async def batch_query_logs(
    query_request: Dict[str, Any],
    db_session = Depends(get_db_session)
):
    """Query multiple log entries with batch optimization"""
    start_time = time.time()
    
    try:
        result = await batch_processor.process_batch_query(
            query_request,
            db_session
        )
        
        processing_time = time.time() - start_time
        
        return {
            "success": True,
            "total_results": len(result.logs),
            "logs": [log.dict() for log in result.logs],
            "processing_time": processing_time,
            "query_stats": result.query_stats
        }
        
    except Exception as e:
        logger.error(f"❌ Batch query failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/v1/logs/batch", response_model=BatchResponse)
async def batch_delete_logs(
    delete_request: Dict[str, Any],
    background_tasks: BackgroundTasks,
    db_session = Depends(get_db_session)
):
    """Delete multiple log entries in a single batch operation"""
    start_time = time.time()
    
    try:
        result = await batch_processor.process_batch_delete(
            delete_request,
            db_session
        )
        
        processing_time = time.time() - start_time
        background_tasks.add_task(
            metrics.record_batch_operation,
            "delete", result.total_processed, processing_time, result.success_count
        )
        
        return BatchResponse(
            success=result.success_count == result.total_processed,
            total_processed=result.total_processed,
            success_count=result.success_count,
            error_count=result.error_count,
            errors=result.errors,
            processing_time=processing_time,
            batch_id=result.batch_id
        )
        
    except Exception as e:
        logger.error(f"❌ Batch delete failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/metrics/batch", response_model=BatchStats)
async def get_batch_metrics():
    """Get current batch operation metrics"""
    return await metrics.get_batch_stats()

@app.get("/api/v1/health")
async def health_check():
    """System health check"""
    return {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "batch_processor": await batch_processor.health_check(),
        "metrics_collector": metrics.is_healthy()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
