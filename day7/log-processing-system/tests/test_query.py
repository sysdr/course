#!/usr/bin/env python3
# test_query.py - Unit tests for the log query component

import unittest
import os
import json
import tempfile
import shutil
import sys

# Assuming query.py is in the parent directory
sys.path.append('..')
from query.query import search_by_pattern, search_by_index

class TestQuery(unittest.TestCase):
    """Test cases for the log query component"""
    
    def setUp(self):
        """Set up test environment"""
        # Create temporary directories for testing
        self.test_dir = tempfile.mkdtemp()
        self.storage_dir = os.path.join(self.test_dir, 'storage')
        
        # Create required subdirectories
        os.makedirs(os.path.join(self.storage_dir, 'active'), exist_ok=True)
        os.makedirs(os.path.join(self.storage_dir, 'archive'), exist_ok=True)
        os.makedirs(os.path.join(self.storage_dir, 'index', 'level', 'INFO'), exist_ok=True)
        os.makedirs(os.path.join(self.storage_dir, 'index', 'level', 'ERROR'), exist_ok=True)
        os.makedirs(os.path.join(self.storage_dir, 'index', 'status', '200'), exist_ok=True)
        os.makedirs(os.path.join(self.storage_dir, 'index', 'status', '404'), exist_ok=True)
        
        # Create sample log files
        self.sample_logs = [
            {
                'timestamp': '2023-09-25T14:23:11',
                'level': 'INFO',
                'message': 'User login successful',
                'ip': '192.168.1.1',
                'method': 'POST',
                'path': '/login',
                'status': 200
            },
            {
                'timestamp': '2023-09-25T14:24:11',
                'level': 'ERROR',
                'message': 'Database connection failed',
                'ip': '192.168.1.2',
                'method': 'GET',
                'path': '/users',
                'status': 500
            },
            {
                'timestamp': '2023-09-25T14:25:11',
                'level': 'INFO',
                'message': 'Page loaded successfully',
                'ip': '192.168.1.3',
                'method': 'GET',
                'path': '/index.html',
                'status': 200
            },
            {
                'timestamp': '2023-09-25T14:26:11',
                'level': 'ERROR',
                'message': 'Page not found',
                'ip': '192.168.1.4',
                'method': 'GET',
                'path': '/nonexistent',
                'status': 404
            }
        ]
        
        # Store sample logs
        self.log_files = []
        for i, log in enumerate(self.sample_logs):
            # Create log file
            log_file = os.path.join(self.storage_dir, 'active', f'log_{i}.json')
            with open(log_file, 'w') as f:
                json.dump(log, f)
            
            self.log_files.append(log_file)
            
            # Create index pointers
            level_index = os.path.join(self.storage_dir, 'index', 'level', log['level'], f'index_{i}.txt')
            with open(level_index, 'w') as f:
                f.write(log_file)
            
            status_index = os.path.join(self.storage_dir, 'index', 'status', str(log['status']), f'index_{i}.txt')
            with open(status_index, 'w') as f:
                f.write(log_file)
    
    def tearDown(self):
        """Clean up after tests"""
        # Remove the temporary directory
        shutil.rmtree(self.test_dir)
    
    def test_search_by_pattern_basic(self):
        """Test basic pattern search functionality"""
        # Search for a term that appears in some logs
        results = search_by_pattern(self.storage_dir, 'login')
        
        # Should find exactly one log
        self.assertEqual(len(results), 1, f"Expected 1 result, got {len(results)}")
        self.assertEqual(results[0]['message'], 'User login successful')
    
    def test_search_by_pattern_multiple_results(self):
        """Test pattern search with multiple results"""
        # Search for a term that appears in multiple logs
        results = search_by_pattern(self.storage_dir, 'success')
        
        # Should find multiple logs
        self.assertEqual(len(results), 2, f"Expected 2 results, got {len(results)}")
        
        # Check the messages contain 'success'
        for result in results:
            self.assertIn('success', result['message'].lower())
    
    def test_search_by_pattern_case_insensitive(self):
        """Test that pattern search is case-insensitive"""
        # Search with different cases
        results_lower = search_by_pattern(self.storage_dir, 'database')
        results_upper = search_by_pattern(self.storage_dir, 'DATABASE')
        results_mixed = search_by_pattern(self.storage_dir, 'DatABasE')
        
        # All should return the same result
        self.assertEqual(len(results_lower), 1)
        self.assertEqual(len(results_upper), 1)
        self.assertEqual(len(results_mixed), 1)
        
        # Check content matches
        self.assertEqual(results_lower[0]['message'], 'Database connection failed')
        self.assertEqual(results_upper[0]['message'], 'Database connection failed')
        self.assertEqual(results_mixed[0]['message'], 'Database connection failed')
    
    def test_search_by_pattern_no_results(self):
        """Test pattern search with no results"""
        # Search for a term that doesn't appear in any logs
        results = search_by_pattern(self.storage_dir, 'nonexistent_term')
        
        # Should find no logs
        self.assertEqual(len(results), 0, f"Expected 0 results, got {len(results)}")
    
    def test_search_by_pattern_in_fields(self):
        """Test pattern search in specific fields"""
        # Search in specific field
        results = search_by_pattern(self.storage_dir, 'GET', fields=['method'])
        
        # Should find exactly 3 logs with GET method
        self.assertEqual(len(results), 3, f"Expected 3 results, got {len(results)}")
        
        # Check all results have GET method
        for result in results:
            self.assertEqual(result['method'], 'GET')
    
    def test_search_by_index_basic(self):
        """Test basic index search functionality"""
        # Search by level=INFO
        results = search_by_index(self.storage_dir, 'level', 'INFO')
        
        # Should find exactly 2 logs
        self.assertEqual(len(results), 2, f"Expected 2 results, got {len(results)}")
        
        # Check all results have INFO level
        for result in results:
            self.assertEqual(result['level'], 'INFO')
    
    def test_search_by_index_status(self):
        """Test index search by status"""
        # Search by status=404
        results = search_by_index(self.storage_dir, 'status', '404')
        
        # Should find exactly 1 log
        self.assertEqual(len(results), 1, f"Expected 1 result, got {len(results)}")
        
        # Check the result has status 404
        self.assertEqual(results[0]['status'], 404)
        self.assertEqual(results[0]['message'], 'Page not found')
    
    def test_search_by_index_nonexistent_index(self):
        """Test search with non-existent index type"""
        # Search by a non-existent index type
        results = search_by_index(self.storage_dir, 'nonexistent_index', 'value')
        
        # Should return empty list (not error)
        self.assertEqual(len(results), 0, f"Expected 0 results, got {len(results)}")
    
    def test_search_by_index_nonexistent_value(self):
        """Test search with non-existent index value"""
        # Search by a non-existent index value
        results = search_by_index(self.storage_dir, 'level', 'DEBUG')
        
        # Should return empty list (not error)
        self.assertEqual(len(results), 0, f"Expected 0 results, got {len(results)}")
    
    def test_search_by_pattern_in_archive(self):
        """Test pattern search includes archived logs"""
        # Create an archived log
        archive_dir = os.path.join(self.storage_dir, 'archive')
        archived_log = {
            'timestamp': '2023-09-25T12:00:00',
            'level': 'INFO',
            'message': 'This is an archived log entry',
            'ip': '192.168.1.5',
            'method': 'GET',
            'path': '/archive',
            'status': 200
        }
        
        archived_file = os.path.join(archive_dir, 'archived_log.json')
        with open(archived_file, 'w') as f:
            json.dump(archived_log, f)
        
        # Search for a term in the archived log
        results = search_by_pattern(self.storage_dir, 'archived')
        
        # Should find the archived log
        self.assertEqual(len(results), 1, f"Expected 1 result, got {len(results)}")
        self.assertEqual(results[0]['message'], 'This is an archived log entry')
    
    def test_search_by_pattern_with_limit(self):
        """Test pattern search with result limit"""
        # Search with a common term but limit results
        results = search_by_pattern(self.storage_dir, 'GET', fields=['method'], limit=2)
        
        # Should only return 2 results even though more match
        self.assertEqual(len(results), 2, f"Expected 2 results (limited), got {len(results)}")
        self.assertEqual(results[0]['method'], 'GET')
        self.assertEqual(results[1]['method'], 'GET')
    
    def test_search_by_pattern_with_sorting(self):
        """Test pattern search with sorting"""
        # Search with sorting by timestamp
        results = search_by_pattern(self.storage_dir, 'GET', fields=['method'], sort_by='timestamp')
        
        # Should return results sorted by timestamp
        timestamps = [result['timestamp'] for result in results]
        self.assertEqual(timestamps, sorted(timestamps), "Results not sorted by timestamp")
    
    def test_search_by_pattern_with_time_range(self):
        """Test pattern search with time range filter"""
        # Search with a time range
        start_time = '2023-09-25T14:24:00'
        end_time = '2023-09-25T14:26:00'
        
        results = search_by_pattern(
            self.storage_dir, 
            'GET', 
            fields=['method'], 
            start_time=start_time,
            end_time=end_time
        )
        
        # Should only return logs within the time range
        self.assertEqual(len(results), 2, f"Expected 2 results within time range, got {len(results)}")
        
        # Check timestamps are within range
        for result in results:
            self.assertTrue(start_time <= result['timestamp'] <= end_time, 
                           f"Result timestamp {result['timestamp']} outside range")
    
    def test_search_combined_pattern_and_index(self):
        """Test combining pattern search with index filtering"""
        # First search by index
        index_results = search_by_index(self.storage_dir, 'level', 'ERROR')
        
        # Then filter these results by pattern
        pattern_results = [log for log in index_results if 'failed' in log['message'].lower()]
        
        # Should find exactly 1 log that matches both criteria
        self.assertEqual(len(pattern_results), 1, f"Expected 1 result for combined search, got {len(pattern_results)}")
        self.assertEqual(pattern_results[0]['message'], 'Database connection failed')
        
        # Verify that a direct combined search would work similarly
        # (assuming the query tool supports this functionality)
        # This is a mock example - the actual implementation would depend on the query tool design
        combined_results = [
            log for log in search_by_index(self.storage_dir, 'level', 'ERROR')
            if 'failed' in log['message'].lower()
        ]
        
        self.assertEqual(len(combined_results), 1)
        self.assertEqual(combined_results[0]['message'], 'Database connection failed')


if __name__ == '__main__':
    unittest.main()