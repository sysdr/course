import pytest
import tempfile
import os
import json
from src.mapreduce.job import MapReduceJob, MapReduceConfig
from src.mapreduce.analyzers import (
    word_count_mapper, word_count_reducer,
    pattern_frequency_mapper, pattern_frequency_reducer
)

class TestMapReduceJob:
    """Test MapReduce job execution"""
    
    def setup_method(self):
        """Setup test environment"""
        self.temp_dir = tempfile.mkdtemp()
        self.config = MapReduceConfig(
            input_path=self.temp_dir,
            output_path=self.temp_dir,
            num_workers=2
        )
    
    def test_job_initialization(self):
        """Test job initialization"""
        job = MapReduceJob(self.config)
        assert job.job_id is not None
        assert job.status.status == "pending"
        assert job.config.num_workers == 2
    
    def test_word_count_mapper(self):
        """Test word count mapper function"""
        test_log = "ERROR: Database connection failed with timeout error"
        results = list(word_count_mapper(test_log))
        
        # Should extract words
        assert len(results) > 0
        # Should be lowercase
        assert all(word.islower() for word, count in results)
        # Should have count of 1 for each word
        assert all(count == 1 for word, count in results)
    
    def test_word_count_reducer(self):
        """Test word count reducer function"""
        key = "error"
        values = [1, 1, 1, 1, 1]
        result_key, result_value = word_count_reducer(key, values)
        
        assert result_key == "error"
        assert result_value == 5
    
    def test_pattern_frequency_mapper(self):
        """Test pattern frequency mapper"""
        test_log = "2024-06-16 10:30:45 ERROR: Connection failed from 192.168.1.100"
        results = list(pattern_frequency_mapper(test_log))
        
        # Should detect patterns
        assert len(results) > 0
        # Should detect error pattern
        error_patterns = [r for r in results if 'error_pattern' in r[0]]
        assert len(error_patterns) > 0
    
    def test_job_status_tracking(self):
        """Test job status tracking"""
        job = MapReduceJob(self.config)
        status = job.get_status()
        
        assert 'job_id' in status
        assert 'status' in status
        assert 'progress' in status
        assert status['status'] == 'pending'

class TestAnalyzers:
    """Test log analyzer functions"""
    
    def test_json_log_parsing(self):
        """Test JSON log parsing"""
        json_log = '{"timestamp": "2024-06-16T10:30:45", "level": "ERROR", "message": "Database connection failed"}'
        results = list(word_count_mapper(json_log))
        
        # Should extract words from message
        words = [word for word, count in results]
        assert 'database' in words
        assert 'connection' in words
        assert 'failed' in words
    
    def test_plain_text_log_parsing(self):
        """Test plain text log parsing"""
        plain_log = "2024-06-16 10:30:45 [ERROR] Authentication service unavailable"
        results = list(word_count_mapper(plain_log))
        
        # Should extract meaningful words
        words = [word for word, count in results]
        assert 'authentication' in words
        assert 'service' in words
        assert 'unavailable' in words
    
    def test_pattern_detection(self):
        """Test pattern detection accuracy"""
        test_logs = [
            "192.168.1.100 - ERROR: Connection timeout",
            "user@example.com login attempt failed",
            "HTTP 404 - Page not found",
            "2024-06-16T10:30:45 - System started"
        ]
        
        for log in test_logs:
            results = list(pattern_frequency_mapper(log))
            assert len(results) > 0  # Should detect at least one pattern
