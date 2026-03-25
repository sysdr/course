import asyncio
import json
import os
import pickle
import time
from collections import defaultdict, Counter
from datetime import datetime
from typing import Dict, List, Set, Tuple, Optional
import structlog
import mmh3

from src.models import LogEntry, IndexSegment, SearchQuery, SearchResult

logger = structlog.get_logger()

class InvertedIndex:
    """Memory-resident inverted index with persistence support"""
    
    def __init__(self, segment_id: str):
        self.segment_id = segment_id
        self.creation_time = datetime.now()
        self.term_to_docs: Dict[str, Set[str]] = defaultdict(set)
        self.doc_to_entry: Dict[str, LogEntry] = {}
        self.doc_to_terms: Dict[str, Set[str]] = defaultdict(set)
        self.document_count = 0
        self.memory_size = 0
        
    async def add_document(self, log_entry: LogEntry) -> None:
        """Add a log entry to the index"""
        start_time = time.time()
        
        doc_id = log_entry.id
        terms = log_entry.extract_searchable_terms()
        
        # Store document
        self.doc_to_entry[doc_id] = log_entry
        self.doc_to_terms[doc_id] = set(terms)
        
        # Update inverted index
        for term in terms:
            self.term_to_docs[term].add(doc_id)
        
        self.document_count += 1
        self.memory_size += len(json.dumps(log_entry.to_dict()))
        
        indexing_time = (time.time() - start_time) * 1000
        logger.info("document_indexed", 
                   doc_id=doc_id, 
                   segment_id=self.segment_id,
                   indexing_time_ms=indexing_time,
                   term_count=len(terms))
    
    async def search(self, query: SearchQuery) -> List[SearchResult]:
        """Search the index for matching documents"""
        if not query.terms:
            return []
        
        start_time = time.time()
        
        # Find documents containing all query terms (AND logic)
        matching_docs = None
        for term in query.terms:
            term_docs = self.term_to_docs.get(term.lower(), set())
            if matching_docs is None:
                matching_docs = term_docs.copy()
            else:
                matching_docs &= term_docs
        
        if not matching_docs:
            return []
        
        # Score and rank results
        results = []
        for doc_id in matching_docs:
            log_entry = self.doc_to_entry[doc_id]
            
            # Apply filters
            if query.filters:
                skip = False
                for filter_key, filter_value in query.filters.items():
                    if filter_key == 'service' and log_entry.service != filter_value:
                        skip = True
                        break
                    elif filter_key == 'level' and log_entry.level != filter_value:
                        skip = True
                        break
                if skip:
                    continue
            
            # Simple scoring: term frequency in document
            doc_terms = self.doc_to_terms[doc_id]
            score = sum(1 for term in query.terms if term.lower() in doc_terms)
            
            results.append(SearchResult(
                log_entry=log_entry,
                score=score,
                segment_id=self.segment_id
            ))
        
        # Sort by score and timestamp
        results.sort(key=lambda r: (-r.score, -r.log_entry.timestamp.timestamp()))
        
        search_time = (time.time() - start_time) * 1000
        logger.info("search_completed",
                   segment_id=self.segment_id,
                   query_terms=query.terms,
                   result_count=len(results),
                   search_time_ms=search_time)
        
        return results[:query.limit]
    
    async def persist_to_disk(self, index_path: str) -> bool:
        """Persist index to disk"""
        try:
            os.makedirs(os.path.dirname(index_path), exist_ok=True)
            
            index_data = {
                'segment_id': self.segment_id,
                'creation_time': self.creation_time.isoformat(),
                'term_to_docs': {term: list(docs) for term, docs in self.term_to_docs.items()},
                'doc_to_entry': {doc_id: entry.to_dict() for doc_id, entry in self.doc_to_entry.items()},
                'document_count': self.document_count
            }
            
            with open(index_path, 'wb') as f:
                pickle.dump(index_data, f)
            
            logger.info("index_persisted", 
                       segment_id=self.segment_id,
                       path=index_path,
                       document_count=self.document_count)
            return True
            
        except Exception as e:
            logger.error("index_persistence_failed", 
                        segment_id=self.segment_id,
                        error=str(e))
            return False
    
    @classmethod
    async def load_from_disk(cls, index_path: str) -> Optional['InvertedIndex']:
        """Load index from disk"""
        try:
            with open(index_path, 'rb') as f:
                index_data = pickle.load(f)
            
            index = cls(index_data['segment_id'])
            index.creation_time = datetime.fromisoformat(index_data['creation_time'])
            index.document_count = index_data['document_count']
            
            # Reconstruct inverted index
            for term, doc_list in index_data['term_to_docs'].items():
                index.term_to_docs[term] = set(doc_list)
            
            # Reconstruct documents
            for doc_id, entry_dict in index_data['doc_to_entry'].items():
                index.doc_to_entry[doc_id] = LogEntry.from_dict(entry_dict)
                index.doc_to_terms[doc_id] = set(index.doc_to_entry[doc_id].extract_searchable_terms())
            
            logger.info("index_loaded", 
                       segment_id=index.segment_id,
                       path=index_path,
                       document_count=index.document_count)
            return index
            
        except Exception as e:
            logger.error("index_load_failed", path=index_path, error=str(e))
            return None
    
    def get_stats(self) -> Dict:
        """Get index statistics"""
        return {
            'segment_id': self.segment_id,
            'creation_time': self.creation_time.isoformat(),
            'document_count': self.document_count,
            'memory_size_bytes': self.memory_size,
            'term_count': len(self.term_to_docs),
            'avg_terms_per_doc': len(self.term_to_docs) / max(1, self.document_count)
        }
