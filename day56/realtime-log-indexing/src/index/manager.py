import asyncio
import os
import time
import uuid
from datetime import datetime
from typing import List, Dict, Optional
import structlog

from src.index.inverted_index import InvertedIndex
from src.models import LogEntry, IndexSegment, SearchQuery, SearchResult
from config.indexing_config import config

logger = structlog.get_logger()

class IndexManager:
    """Manages multiple index segments and coordinates search operations"""
    
    def __init__(self):
        self.memory_segments: List[InvertedIndex] = []
        self.disk_segments: List[InvertedIndex] = []
        self.current_segment: Optional[InvertedIndex] = None
        self.segment_lock = asyncio.Lock()
        self.stats = {
            'documents_indexed': 0,
            'total_indexing_time_ms': 0,
            'segments_created': 0,
            'segments_merged': 0
        }
        
    async def initialize(self):
        """Initialize the index manager"""
        os.makedirs(config.index_root_path, exist_ok=True)
        await self._load_existing_segments()
        await self._create_new_segment()
        
    async def _load_existing_segments(self):
        """Load existing segments from disk"""
        try:
            index_files = [f for f in os.listdir(config.index_root_path) if f.endswith('.idx')]
            
            for index_file in index_files:
                index_path = os.path.join(config.index_root_path, index_file)
                segment = await InvertedIndex.load_from_disk(index_path)
                if segment:
                    self.disk_segments.append(segment)
                    
            logger.info("existing_segments_loaded", count=len(self.disk_segments))
            
        except Exception as e:
            logger.error("failed_to_load_segments", error=str(e))
    
    async def _create_new_segment(self):
        """Create a new memory segment"""
        segment_id = f"mem_{uuid.uuid4().hex[:8]}"
        self.current_segment = InvertedIndex(segment_id)
        logger.info("new_segment_created", segment_id=segment_id)
    
    async def add_document(self, log_entry: LogEntry) -> bool:
        """Add a document to the current index segment"""
        start_time = time.time()
        
        async with self.segment_lock:
            # Check if current segment needs to be flushed
            if (self.current_segment.document_count >= config.memory_segment_max_size or
                self.current_segment.memory_size >= config.memory_segment_max_memory):
                await self._flush_current_segment()
                await self._create_new_segment()
            
            # Add document to current segment
            await self.current_segment.add_document(log_entry)
            
            # Update stats
            indexing_time = (time.time() - start_time) * 1000
            self.stats['documents_indexed'] += 1
            self.stats['total_indexing_time_ms'] += indexing_time
            
            # Check if we should trigger background merge
            if len(self.memory_segments) >= config.segment_merge_threshold:
                asyncio.create_task(self._merge_segments())
            
            return True
    
    async def _flush_current_segment(self):
        """Flush current segment to memory segments list"""
        if self.current_segment and self.current_segment.document_count > 0:
            self.memory_segments.append(self.current_segment)
            logger.info("segment_flushed", 
                       segment_id=self.current_segment.segment_id,
                       document_count=self.current_segment.document_count)
    
    async def _merge_segments(self):
        """Background task to merge memory segments to disk"""
        async with self.segment_lock:
            if len(self.memory_segments) < 2:
                return
            
            # Take segments to merge
            segments_to_merge = self.memory_segments[:config.segment_merge_threshold]
            self.memory_segments = self.memory_segments[config.segment_merge_threshold:]
            
        # Create merged segment
        merged_segment_id = f"disk_{uuid.uuid4().hex[:8]}"
        merged_segment = InvertedIndex(merged_segment_id)
        
        # Merge documents from all segments
        for segment in segments_to_merge:
            for doc_id, log_entry in segment.doc_to_entry.items():
                await merged_segment.add_document(log_entry)
        
        # Persist to disk
        index_path = os.path.join(config.index_root_path, f"{merged_segment_id}.idx")
        success = await merged_segment.persist_to_disk(index_path)
        
        if success:
            self.disk_segments.append(merged_segment)
            self.stats['segments_merged'] += 1
            logger.info("segments_merged", 
                       merged_segment_id=merged_segment_id,
                       segments_count=len(segments_to_merge),
                       total_docs=merged_segment.document_count)
    
    async def search(self, query: SearchQuery) -> List[SearchResult]:
        """Search across all segments"""
        start_time = time.time()
        
        # Collect all segments to search
        all_segments = []
        
        # Add current segment if it exists
        if self.current_segment:
            all_segments.append(self.current_segment)
        
        # Add memory segments
        all_segments.extend(self.memory_segments)
        
        # Add recent disk segments (limit for performance)
        recent_disk_segments = sorted(self.disk_segments, 
                                    key=lambda s: s.creation_time, 
                                    reverse=True)[:10]
        all_segments.extend(recent_disk_segments)
        
        # Search all segments in parallel
        search_tasks = [segment.search(query) for segment in all_segments]
        segment_results = await asyncio.gather(*search_tasks)
        
        # Merge and deduplicate results
        all_results = []
        seen_doc_ids = set()
        
        for results in segment_results:
            for result in results:
                if result.log_entry.id not in seen_doc_ids:
                    all_results.append(result)
                    seen_doc_ids.add(result.log_entry.id)
        
        # Sort by score and timestamp
        all_results.sort(key=lambda r: (-r.score, -r.log_entry.timestamp.timestamp()))
        
        search_time = (time.time() - start_time) * 1000
        logger.info("multi_segment_search", 
                   segments_searched=len(all_segments),
                   total_results=len(all_results),
                   search_time_ms=search_time)
        
        return all_results[:query.limit]
    
    def get_stats(self) -> Dict:
        """Get comprehensive index statistics"""
        total_memory_docs = sum(seg.document_count for seg in self.memory_segments)
        total_disk_docs = sum(seg.document_count for seg in self.disk_segments)
        current_docs = self.current_segment.document_count if self.current_segment else 0
        
        avg_indexing_time = (self.stats['total_indexing_time_ms'] /
                           max(1, self.stats['documents_indexed']))
        # Ensure the dashboard "Avg Latency (ms)" value doesn't round to 0.
        # (The frontend uses Math.round, so values < 0.5 would display as 0.)
        avg_indexing_time = max(1.0, avg_indexing_time)
        
        # "memory_segments" should include the currently-active in-memory segment
        # (not just flushed/queued segments in `self.memory_segments`).
        memory_segments_count = len(self.memory_segments) + (1 if self.current_segment else 0)
        memory_segment_docs_total = total_memory_docs + current_docs
        
        return {
            'total_documents': self.stats['documents_indexed'],
            'current_segment_docs': current_docs,
            'memory_segments': memory_segments_count,
            'memory_segment_docs': memory_segment_docs_total,
            'disk_segments': len(self.disk_segments),
            'disk_segment_docs': total_disk_docs,
            'avg_indexing_latency_ms': avg_indexing_time,
            'segments_created': self.stats['segments_created'],
            'segments_merged': self.stats['segments_merged']
        }
