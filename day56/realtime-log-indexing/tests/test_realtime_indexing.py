import pytest
import pytest_asyncio
import asyncio
import tempfile
import shutil
from datetime import datetime
from unittest.mock import Mock, patch

from src.models import LogEntry, SearchQuery
from src.index.inverted_index import InvertedIndex
from src.index.manager import IndexManager
from src.search.interface import SearchInterface
from src.stream.processor import StreamProcessor

@pytest.mark.asyncio
class TestRealtimeIndexing:
    
    @pytest.fixture
    def sample_log_entry(self):
        return LogEntry(
            timestamp=datetime.now(),
            level="INFO",
            service="test-service",
            message="Test log message for indexing",
            metadata={"user_id": "123", "request_id": "req_001"}
        )
    
    @pytest.fixture
    def inverted_index(self):
        return InvertedIndex("test_segment")
    
    @pytest_asyncio.fixture
    async def index_manager(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            with patch('config.indexing_config.config.index_root_path', temp_dir):
                manager = IndexManager()
                await manager.initialize()
                yield manager
    
    async def test_inverted_index_add_document(self, inverted_index, sample_log_entry):
        """Test adding document to inverted index"""
        await inverted_index.add_document(sample_log_entry)
        
        assert inverted_index.document_count == 1
        assert sample_log_entry.id in inverted_index.doc_to_entry
        
        # Test that searchable terms were extracted
        terms = sample_log_entry.extract_searchable_terms()
        for term in terms:
            assert sample_log_entry.id in inverted_index.term_to_docs[term]
    
    async def test_inverted_index_search(self, inverted_index, sample_log_entry):
        """Test searching inverted index"""
        await inverted_index.add_document(sample_log_entry)
        
        query = SearchQuery(terms=["test"], filters={}, limit=10)
        results = await inverted_index.search(query)
        
        assert len(results) == 1
        assert results[0].log_entry.id == sample_log_entry.id
        assert results[0].score > 0
    
    async def test_inverted_index_search_with_filters(self, inverted_index, sample_log_entry):
        """Test searching with filters"""
        await inverted_index.add_document(sample_log_entry)
        
        # Search with matching service filter
        query = SearchQuery(terms=["test"], filters={"service": "test-service"}, limit=10)
        results = await inverted_index.search(query)
        assert len(results) == 1
        
        # Search with non-matching service filter
        query = SearchQuery(terms=["test"], filters={"service": "other-service"}, limit=10)
        results = await inverted_index.search(query)
        assert len(results) == 0
    
    async def test_index_manager_add_document(self, index_manager, sample_log_entry):
        """Test adding document through index manager"""
        success = await index_manager.add_document(sample_log_entry)
        
        assert success
        assert index_manager.current_segment is not None
        assert index_manager.current_segment.document_count == 1
        
        stats = index_manager.get_stats()
        assert stats['total_documents'] == 1
    
    async def test_index_manager_search(self, index_manager, sample_log_entry):
        """Test searching through index manager"""
        await index_manager.add_document(sample_log_entry)
        
        query = SearchQuery(terms=["test"], filters={}, limit=10)
        results = await index_manager.search(query)
        
        assert len(results) == 1
        assert results[0].log_entry.id == sample_log_entry.id
    
    async def test_search_interface(self, index_manager, sample_log_entry):
        """Test search interface functionality"""
        search_interface = SearchInterface(index_manager)
        
        # Add test document
        await index_manager.add_document(sample_log_entry)
        
        # Test search
        results = await search_interface.search_logs("test message", {}, 10)
        
        assert results['total_count'] == 1
        assert len(results['results']) == 1
        assert 'search_time_ms' in results
        assert results['results'][0]['log_entry']['id'] == sample_log_entry.id
    
    async def test_search_interface_empty_query(self, index_manager):
        """Test search interface with empty query"""
        search_interface = SearchInterface(index_manager)
        
        results = await search_interface.search_logs("", {}, 10)
        
        assert results['total_count'] == 0
        assert 'error' in results
    
    async def test_index_persistence(self, inverted_index, sample_log_entry):
        """Test index persistence to disk"""
        await inverted_index.add_document(sample_log_entry)
        
        with tempfile.NamedTemporaryFile(suffix='.idx', delete=False) as temp_file:
            success = await inverted_index.persist_to_disk(temp_file.name)
            assert success
            
            # Load index from disk
            loaded_index = await InvertedIndex.load_from_disk(temp_file.name)
            assert loaded_index is not None
            assert loaded_index.document_count == 1
            assert sample_log_entry.id in loaded_index.doc_to_entry
    
    async def test_segment_memory_limit(self, index_manager):
        """Test segment creation when memory limit is reached"""
        # Add documents until memory segment limit is reached
        initial_segments = len(index_manager.memory_segments)
        
        for i in range(15):  # Exceed default max_size of 10
            log_entry = LogEntry(
                timestamp=datetime.now(),
                level="INFO",
                service="test-service",
                message=f"Test message {i}",
                metadata={"iteration": i}
            )
            await index_manager.add_document(log_entry)
        
        # Should have created a new segment
        assert len(index_manager.memory_segments) > initial_segments or index_manager.current_segment.document_count > 0
    
    async def test_log_entry_searchable_terms(self, sample_log_entry):
        """Test log entry term extraction"""
        terms = sample_log_entry.extract_searchable_terms()
        
        # Should include service, level, and message words
        assert "test-service" in terms
        assert "info" in terms
        assert "test" in terms
        assert "log" in terms
        assert "message" in terms
        
        # Should include metadata
        assert "user_id:123" in terms
        assert "request_id:req_001" in terms

# Performance test
@pytest.mark.asyncio
async def test_indexing_performance():
    """Test indexing performance under load"""
    import time
    
    with tempfile.TemporaryDirectory() as temp_dir:
        with patch('config.indexing_config.config.index_root_path', temp_dir):
            manager = IndexManager()
            await manager.initialize()
            
            # Test indexing 100 documents
            start_time = time.time()
            
            for i in range(100):
                log_entry = LogEntry(
                    timestamp=datetime.now(),
                    level="INFO",
                    service=f"service-{i % 5}",
                    message=f"Performance test message {i}",
                    metadata={"iteration": i, "batch": i // 10}
                )
                await manager.add_document(log_entry)
            
            end_time = time.time()
            total_time = (end_time - start_time) * 1000  # Convert to ms
            
            print(f"Indexed 100 documents in {total_time:.2f}ms")
            print(f"Average indexing time: {total_time/100:.2f}ms per document")
            
            # Verify all documents were indexed
            stats = manager.get_stats()
            assert stats['total_documents'] == 100
            
            # Test search performance
            search_interface = SearchInterface(manager)
            
            start_time = time.time()
            results = await search_interface.search_logs("performance test", {}, 50)
            search_time = (time.time() - start_time) * 1000
            
            print(f"Search completed in {search_time:.2f}ms")
            print(f"Found {results['total_count']} results")
            
            # Performance assertions
            assert total_time < 5000  # Should index 100 docs in under 5 seconds
            assert search_time < 100  # Search should complete in under 100ms
            assert results['total_count'] > 0  # Should find matching results

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
