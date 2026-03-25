import asyncio
import time
from typing import List, Dict, Any
import structlog

from src.models import SearchQuery, SearchResult, LogEntry
from src.index.manager import IndexManager

logger = structlog.get_logger()

class SearchInterface:
    """Provides search capabilities across indexed logs"""
    
    def __init__(self, index_manager: IndexManager):
        self.index_manager = index_manager
        self.search_stats = {
            'searches_performed': 0,
            'total_search_time_ms': 0,
            'total_results_returned': 0
        }
    
    async def search_logs(self, 
                         query_text: str, 
                         filters: Dict[str, str] = None,
                         limit: int = 100) -> Dict[str, Any]:
        """Search logs with query text and optional filters"""
        start_time = time.time()
        
        # Parse query text into terms
        terms = [term.strip().lower() for term in query_text.split() if term.strip()]
        
        if not terms:
            return {
                'results': [],
                'total_count': 0,
                'search_time_ms': 0,
                'error': 'Empty query'
            }
        
        # Create search query
        query = SearchQuery(
            terms=terms,
            filters=filters or {},
            limit=limit,
            include_recent=True
        )
        
        try:
            # Execute search
            results = await self.index_manager.search(query)
            
            # Convert results to serializable format
            serialized_results = []
            for result in results:
                serialized_results.append({
                    'log_entry': result.log_entry.to_dict(),
                    'score': result.score,
                    'segment_id': result.segment_id
                })
            
            search_time = (time.time() - start_time) * 1000
            
            # Update stats
            self.search_stats['searches_performed'] += 1
            self.search_stats['total_search_time_ms'] += search_time
            self.search_stats['total_results_returned'] += len(results)
            
            logger.info("search_completed",
                       query_text=query_text,
                       filters=filters,
                       result_count=len(results),
                       search_time_ms=search_time)
            
            return {
                'results': serialized_results,
                'total_count': len(results),
                'search_time_ms': search_time,
                'query': {
                    'text': query_text,
                    'terms': terms,
                    'filters': filters
                }
            }
            
        except Exception as e:
            search_time = (time.time() - start_time) * 1000
            logger.error("search_error", 
                        query_text=query_text,
                        error=str(e),
                        search_time_ms=search_time)
            
            return {
                'results': [],
                'total_count': 0,
                'search_time_ms': search_time,
                'error': str(e)
            }
    
    async def get_recent_logs(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Get recently indexed logs"""
        query = SearchQuery(
            terms=['*'],  # Match all
            filters={},
            limit=limit
        )
        
        results = await self.index_manager.search(query)
        
        return [{
            'log_entry': result.log_entry.to_dict(),
            'score': result.score,
            'segment_id': result.segment_id
        } for result in results]
    
    def get_stats(self) -> Dict[str, Any]:
        """Get search statistics"""
        avg_search_time = (self.search_stats['total_search_time_ms'] / 
                          max(1, self.search_stats['searches_performed']))
        
        avg_results_per_search = (self.search_stats['total_results_returned'] / 
                                 max(1, self.search_stats['searches_performed']))
        
        return {
            'searches_performed': self.search_stats['searches_performed'],
            'avg_search_time_ms': avg_search_time,
            'avg_results_per_search': avg_results_per_search,
            'total_results_returned': self.search_stats['total_results_returned']
        }
