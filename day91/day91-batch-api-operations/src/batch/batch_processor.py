import asyncio
import asyncpg
import json
import uuid
import time
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone
from dataclasses import dataclass
import logging

from ..models.log_models import LogEntry, BatchResult, QueryResult

logger = logging.getLogger(__name__)

@dataclass
class ProcessingChunk:
    chunk_id: str
    logs: List[LogEntry]
    start_index: int
    end_index: int

class BatchProcessor:
    def __init__(self):
        self.db_pool = None
        self.max_chunk_size = 1000
        self.max_concurrent_chunks = 10
        
    async def initialize(self):
        """Initialize database connection pool"""
        try:
            self.db_pool = await asyncpg.create_pool(
                host='localhost',
                port=5432,
                user='postgres',
                password='postgres',
                database='logdb',
                min_size=5,
                max_size=20
            )
            logger.info("✅ Database connection pool initialized")
        except Exception as e:
            logger.warning(f"⚠️ Database connection failed, using in-memory storage: {e}")
            self.db_pool = None
    
    async def process_batch_insert(
        self, 
        logs: List[LogEntry], 
        db_session,
        chunk_size: int = 1000
    ) -> BatchResult:
        """Process batch insert with chunking and parallel execution"""
        batch_id = str(uuid.uuid4())
        start_time = time.time()
        
        try:
            # Split into chunks
            chunks = self._create_chunks(logs, chunk_size, batch_id)
            logger.info(f"📊 Split {len(logs)} logs into {len(chunks)} chunks")
            
            # Process chunks in parallel
            semaphore = asyncio.Semaphore(self.max_concurrent_chunks)
            tasks = [
                self._process_insert_chunk(chunk, semaphore)
                for chunk in chunks
            ]
            
            chunk_results = await asyncio.gather(*tasks, return_exceptions=True)
            
            # Aggregate results
            success_count = 0
            error_count = 0
            errors = []
            
            for i, result in enumerate(chunk_results):
                if isinstance(result, Exception):
                    error_count += len(chunks[i].logs)
                    errors.append(f"Chunk {chunks[i].chunk_id}: {str(result)}")
                else:
                    success_count += result.get('success_count', 0)
                    error_count += result.get('error_count', 0)
                    if result.get('errors'):
                        errors.extend(result['errors'])
            
            processing_time = time.time() - start_time
            logger.info(f"✅ Batch {batch_id} completed: {success_count} success, {error_count} errors in {processing_time:.2f}s")
            
            return BatchResult(
                batch_id=batch_id,
                success_count=success_count,
                error_count=error_count,
                total_processed=len(logs),
                processing_time=processing_time,
                errors=errors
            )
            
        except Exception as e:
            logger.error(f"❌ Batch insert failed: {str(e)}")
            return BatchResult(
                batch_id=batch_id,
                success_count=0,
                error_count=len(logs),
                total_processed=len(logs),
                processing_time=time.time() - start_time,
                errors=[str(e)]
            )
    
    async def _process_insert_chunk(self, chunk: ProcessingChunk, semaphore: asyncio.Semaphore):
        """Process a single chunk of logs"""
        async with semaphore:
            try:
                if self.db_pool:
                    return await self._insert_chunk_to_db(chunk)
                else:
                    return await self._insert_chunk_to_memory(chunk)
            except Exception as e:
                logger.error(f"❌ Chunk {chunk.chunk_id} failed: {str(e)}")
                raise
    
    async def _insert_chunk_to_db(self, chunk: ProcessingChunk):
        """Insert chunk to PostgreSQL database"""
        async with self.db_pool.acquire() as conn:
            async with conn.transaction():
                success_count = 0
                error_count = 0
                errors = []
                
                for log in chunk.logs:
                    try:
                        await conn.execute("""
                            INSERT INTO logs (id, timestamp, level, service, message, metadata, batch_id)
                            VALUES ($1, $2, $3, $4, $5, $6, $7)
                        """, 
                        log.id, log.timestamp, log.level, 
                        log.service, log.message, 
                        json.dumps(log.metadata), chunk.chunk_id)
                        success_count += 1
                    except Exception as e:
                        error_count += 1
                        errors.append(f"Log {log.id}: {str(e)}")
                
                return {
                    'success_count': success_count,
                    'error_count': error_count,
                    'errors': errors
                }
    
    async def _insert_chunk_to_memory(self, chunk: ProcessingChunk):
        """Insert chunk to in-memory storage (fallback)"""
        # Simulate database insert with delay
        await asyncio.sleep(0.1)
        
        success_count = len(chunk.logs)
        logger.info(f"💾 Inserted chunk {chunk.chunk_id}: {success_count} logs to memory")
        
        return {
            'success_count': success_count,
            'error_count': 0,
            'errors': []
        }
    
    def _create_chunks(self, logs: List[LogEntry], chunk_size: int, batch_id: str) -> List[ProcessingChunk]:
        """Split logs into processing chunks"""
        chunks = []
        
        for i in range(0, len(logs), chunk_size):
            chunk_logs = logs[i:i + chunk_size]
            chunk = ProcessingChunk(
                chunk_id=f"{batch_id}-{i//chunk_size}",
                logs=chunk_logs,
                start_index=i,
                end_index=min(i + chunk_size, len(logs))
            )
            chunks.append(chunk)
        
        return chunks
    
    async def process_batch_query(self, query_request: Dict[str, Any], db_session) -> QueryResult:
        """Process batch query operations"""
        start_time = time.time()
        
        # Simulate query processing
        await asyncio.sleep(0.05)  # Simulate query time
        
        # Return mock data for demonstration
        sample_logs = [
            LogEntry(
                id=f"query-{i}",
                timestamp=datetime.now(timezone.utc),
                level="INFO",
                service="batch-api",
                message=f"Sample log entry {i}",
                metadata={"query": "batch_operation"}
            )
            for i in range(50)  # Return 50 sample logs
        ]
        
        processing_time = time.time() - start_time
        
        return QueryResult(
            logs=sample_logs,
            total_count=len(sample_logs),
            processing_time=processing_time,
            query_stats={
                "execution_time": processing_time,
                "rows_scanned": 1000,
                "index_usage": "primary_key"
            }
        )
    
    async def process_batch_delete(self, delete_request: Dict[str, Any], db_session) -> BatchResult:
        """Process batch delete operations"""
        batch_id = str(uuid.uuid4())
        start_time = time.time()
        
        # Simulate delete processing
        await asyncio.sleep(0.1)
        
        # Mock successful deletion
        total_processed = delete_request.get('count', 100)
        
        processing_time = time.time() - start_time
        
        return BatchResult(
            batch_id=batch_id,
            success_count=total_processed,
            error_count=0,
            total_processed=total_processed,
            processing_time=processing_time,
            errors=[]
        )
    
    async def health_check(self) -> Dict[str, Any]:
        """Check batch processor health"""
        return {
            "status": "healthy",
            "database_pool": "connected" if self.db_pool else "disconnected",
            "max_chunk_size": self.max_chunk_size,
            "max_concurrent_chunks": self.max_concurrent_chunks
        }
