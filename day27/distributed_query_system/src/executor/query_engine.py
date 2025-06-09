import os
import json
import asyncio
import aiofiles
from typing import List, Dict, Any, Optional
from datetime import datetime
import structlog
from ..common.query_types import Query, QueryFilter, TimeRange

logger = structlog.get_logger()

class QueryEngine:
    def __init__(self, data_dir: str):
        self.data_dir = data_dir
        self.indexes: Dict[str, Dict[str, List[int]]] = {}
        self.log_files: List[str] = []
        self.loaded_data: List[Dict[str, Any]] = []
    
    async def initialize(self):
        """Initialize the query engine and load data"""
        os.makedirs(self.data_dir, exist_ok=True)
        await self._load_log_files()
        await self._build_indexes()
        logger.info("Query engine initialized", 
                   files_loaded=len(self.log_files),
                   records_loaded=len(self.loaded_data))
    
    async def cleanup(self):
        """Cleanup resources"""
        self.indexes.clear()
        self.loaded_data.clear()
        self.log_files.clear()
    
    async def _load_log_files(self):
        """Load all log files from data directory"""
        os.makedirs(self.data_dir, exist_ok=True)
        
        # Check if any .jsonl files exist
        jsonl_files = [f for f in os.listdir(self.data_dir) if f.endswith('.jsonl')]
        
        if not jsonl_files:
            # No data files exist, create sample data
            await self._create_sample_data()
            return
        
        # Load existing files
        for filename in jsonl_files:
            file_path = os.path.join(self.data_dir, filename)
            await self._load_single_file(file_path)
            self.log_files.append(file_path)
        
        # If no data was loaded from files, create sample data
        if not self.loaded_data:
            await self._create_sample_data()
    
    async def _load_single_file(self, file_path: str):
        """Load a single JSONL file"""
        try:
            async with aiofiles.open(file_path, 'r') as f:
                async for line in f:
                    if line.strip():
                        log_entry = json.loads(line.strip())
                        self.loaded_data.append(log_entry)
        except Exception as e:
            logger.error("Failed to load file", file_path=file_path, error=str(e))
    
    async def _create_sample_data(self):
        """Create sample log data for testing"""
        sample_logs = []
        base_time = datetime.now()
        
        for i in range(1000):
            log_entry = {
                "timestamp": (base_time.timestamp() + i),
                "level": "INFO" if i % 3 == 0 else "ERROR" if i % 7 == 0 else "DEBUG",
                "service": f"service-{i % 5}",
                "message": f"Sample log message {i}",
                "user_id": f"user_{i % 100}",
                "request_id": f"req_{i}",
                "duration_ms": (i % 1000) + 10,
                "status_code": 200 if i % 4 == 0 else 500 if i % 13 == 0 else 404
            }
            sample_logs.append(log_entry)
        
        # Save sample data
        os.makedirs(self.data_dir, exist_ok=True)
        sample_file = os.path.join(self.data_dir, "sample_logs.jsonl")
        
        try:
            async with aiofiles.open(sample_file, 'w') as f:
                for log_entry in sample_logs:
                    await f.write(json.dumps(log_entry) + '\n')
            
            # Also load into memory immediately
            self.loaded_data.extend(sample_logs)
            self.log_files.append(sample_file)
            
            logger.info("Sample data created", 
                       file=sample_file, 
                       records=len(sample_logs))
                       
        except Exception as e:
            logger.error("Failed to create sample data", error=str(e))
            # Fallback: load data directly into memory without file
            self.loaded_data.extend(sample_logs)
            logger.info("Sample data loaded in memory only", records=len(sample_logs))
    
    async def _build_indexes(self):
        """Build indexes for common query fields"""
        index_fields = ["level", "service", "user_id", "status_code"]
        
        for field in index_fields:
            self.indexes[field] = {}
            
            for idx, log_entry in enumerate(self.loaded_data):
                if field in log_entry:
                    value = str(log_entry[field])
                    if value not in self.indexes[field]:
                        self.indexes[field][value] = []
                    self.indexes[field][value].append(idx)
    
    async def search(self, query: Query) -> List[Dict[str, Any]]:
        """Search for log entries matching the query"""
        # Start with all records
        matching_indices = set(range(len(self.loaded_data)))
        
        # Apply filters
        for filter_obj in query.filters:
            filter_indices = await self._apply_filter(filter_obj)
            matching_indices &= filter_indices
        
        # Apply time range filter
        if query.time_range:
            time_indices = await self._apply_time_filter(query.time_range)
            matching_indices &= time_indices
        
        # Get matching records
        results = [self.loaded_data[i] for i in matching_indices]
        
        # Sort results
        results = await self._sort_results(results, query.sort_field, query.sort_order)
        
        # Apply field selection
        if query.include_fields:
            results = self._select_fields(results, query.include_fields)
        elif query.exclude_fields:
            results = self._exclude_fields(results, query.exclude_fields)
        
        return results
    
    async def _apply_filter(self, filter_obj: QueryFilter) -> set:
        """Apply a single filter and return matching indices"""
        # Try to use index if available
        if (filter_obj.field in self.indexes and 
            filter_obj.operator == "eq"):
            
            value = str(filter_obj.value)
            if value in self.indexes[filter_obj.field]:
                return set(self.indexes[filter_obj.field][value])
            else:
                return set()
        
        # Fall back to linear scan
        matching_indices = set()
        for idx, log_entry in enumerate(self.loaded_data):
            if filter_obj.matches(log_entry):
                matching_indices.add(idx)
        
        return matching_indices
    
    async def _apply_time_filter(self, time_range: TimeRange) -> set:
        """Apply time range filter"""
        matching_indices = set()
        
        for idx, log_entry in enumerate(self.loaded_data):
            if "timestamp" in log_entry:
                entry_time = datetime.fromtimestamp(log_entry["timestamp"])
                if time_range.start <= entry_time <= time_range.end:
                    matching_indices.add(idx)
        
        return matching_indices
    
    async def _sort_results(self, results: List[Dict[str, Any]], 
                           sort_field: str, sort_order: str) -> List[Dict[str, Any]]:
        """Sort results by specified field and order"""
        try:
            reverse = (sort_order == "desc")
            
            return sorted(results, 
                         key=lambda x: x.get(sort_field, 0), 
                         reverse=reverse)
        except Exception as e:
            logger.warning("Sort failed, returning unsorted results", error=str(e))
            return results
    
    def _select_fields(self, results: List[Dict[str, Any]], 
                      include_fields: List[str]) -> List[Dict[str, Any]]:
        """Select only specified fields from results"""
        return [
            {field: entry.get(field) for field in include_fields}
            for entry in results
        ]
    
    def _exclude_fields(self, results: List[Dict[str, Any]], 
                       exclude_fields: List[str]) -> List[Dict[str, Any]]:
        """Exclude specified fields from results"""
        return [
            {k: v for k, v in entry.items() if k not in exclude_fields}
            for entry in results
        ]
    
    async def get_stats(self) -> Dict[str, Any]:
        """Get statistics about loaded data"""
        return {
            "total_records": len(self.loaded_data),
            "files_loaded": len(self.log_files),
            "indexes_built": len(self.indexes),
            "index_fields": list(self.indexes.keys())
        }
    
    async def get_time_ranges(self) -> List[Dict[str, str]]:
        """Get time ranges covered by this partition's data"""
        if not self.loaded_data:
            return []
        
        timestamps = [
            entry.get("timestamp", 0) 
            for entry in self.loaded_data 
            if "timestamp" in entry
        ]
        
        if not timestamps:
            return []
        
        min_time = min(timestamps)
        max_time = max(timestamps)
        
        return [{
            "start": datetime.fromtimestamp(min_time).isoformat(),
            "end": datetime.fromtimestamp(max_time).isoformat()
        }]
