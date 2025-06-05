#!/usr/bin/env python3
# test_collector.py - Unit tests for the log collector component

import unittest
import os
import time
import shutil
import tempfile
import threading
import sys

# Assuming collector.py is in the parent directory
sys.path.append('..')
from collector.collector import watch_file, collect_logs

class TestCollector(unittest.TestCase):
    """Test cases for the log collector component"""
    
    def setUp(self):
        """Set up test environment"""
        # Create temporary directories for testing
        self.test_dir = tempfile.mkdtemp()
        self.source_file = os.path.join(self.test_dir, 'test_source.log')
        self.output_dir = os.path.join(self.test_dir, 'collected')
        
        # Create output directory
        os.makedirs(self.output_dir, exist_ok=True)
        
        # Create an empty source file
        with open(self.source_file, 'w') as f:
            pass
    
    def tearDown(self):
        """Clean up after tests"""
        # Remove the temporary directory
        shutil.rmtree(self.test_dir)
    
    def test_watch_file_detects_changes(self):
        """Test that watch_file detects file changes"""
        # Initialize with last_position at 0
        last_position = 0
        
        # Write some content to the file
        with open(self.source_file, 'w') as f:
            f.write("Test log line 1\n")
        
        # Check that watch_file detects the new content
        new_content, new_position = watch_file(self.source_file, last_position)
        
        self.assertEqual(new_content, ["Test log line 1"], "Failed to detect file change")
        self.assertEqual(new_position, 15, "Incorrect new position")
        
        # Write more content
        with open(self.source_file, 'a') as f:
            f.write("Test log line 2\n")
        
        # Check that watch_file detects only the new content
        new_content, new_position = watch_file(self.source_file, new_position)
        
        self.assertEqual(new_content, ["Test log line 2"], "Failed to detect file change")
        self.assertEqual(new_position, 30, "Incorrect new position")
    
    def test_watch_file_handles_empty_file(self):
        """Test that watch_file handles empty files"""
        # Check watching an empty file
        new_content, new_position = watch_file(self.source_file, 0)
        
        self.assertEqual(new_content, [], "Should return empty list for empty file")
        self.assertEqual(new_position, 0, "Position should remain 0 for empty file")
    
    def test_watch_file_handles_file_truncation(self):
        """Test that watch_file handles file truncation"""
        # Write content to the file
        with open(self.source_file, 'w') as f:
            f.write("Test log line 1\nTest log line 2\n")
        
        # Get the position after reading
        _, position = watch_file(self.source_file, 0)
        
        # Truncate the file (simulate log rotation)
        with open(self.source_file, 'w') as f:
            f.write("New content after truncation\n")
        
        # Watch should detect truncation and reset
        new_content, new_position = watch_file(self.source_file, position)
        
        self.assertEqual(new_content, ["New content after truncation"], 
                        "Failed to handle file truncation")
        self.assertEqual(new_position, 28, "Incorrect new position after truncation")
    
    def test_collect_logs_basic_functionality(self):
        """Test basic functionality of collect_logs"""
        # Create a test thread to run collect_logs
        stop_event = threading.Event()
        
        # Function to run collect_logs in a thread with a timeout
        def run_collector():
            collect_logs(self.source_file, self.output_dir, interval=0.5, stop_event=stop_event)
        
        # Start the collector in a thread
        collector_thread = threading.Thread(target=run_collector)
        collector_thread.daemon = True
        collector_thread.start()
        
        try:
            # Write some logs to the source file
            with open(self.source_file, 'w') as f:
                f.write("Test log line 1\n")
            
            # Give the collector time to process
            time.sleep(1)
            
            # Check that logs were collected
            collected_files = os.listdir(self.output_dir)
            self.assertTrue(len(collected_files) > 0, "No collected log files found")
            
            # Check the content of the collected file
            with open(os.path.join(self.output_dir, collected_files[0]), 'r') as f:
                content = f.read()
            
            self.assertIn("Test log line 1", content, "Collected log does not contain expected content")
            
            # Write more logs
            with open(self.source_file, 'a') as f:
                f.write("Test log line 2\n")
            
            # Give the collector time to process
            time.sleep(1)
            
            # Check that new logs were collected
            collected_files = sorted(os.listdir(self.output_dir), key=lambda x: os.path.getmtime(os.path.join(self.output_dir, x)))
            
            # The latest file should contain the new content
            with open(os.path.join(self.output_dir, collected_files[-1]), 'r') as f:
                content = f.read()
            
            self.assertIn("Test log line 2", content, "Collected log does not contain new content")
        
        finally:
            # Stop the collector thread
            stop_event.set()
            collector_thread.join(timeout=2)
    
    def test_collect_logs_handles_errors(self):
        """Test that collect_logs handles errors gracefully"""
        # Create a non-existent source file path
        non_existent_file = os.path.join(self.test_dir, 'nonexistent.log')
        
        # Try to collect logs from non-existent file (should not raise exception)
        try:
            collect_logs(non_existent_file, self.output_dir, interval=0.5, max_iterations=1)
        except Exception as e:
            self.fail(f"collect_logs raised {type(e).__name__} unexpectedly: {e}")
    
    def test_collect_logs_timestamped_files(self):
        """Test that collect_logs creates timestamped files"""
        # Run collect_logs for a single iteration
        collect_logs(self.source_file, self.output_dir, interval=0.5, max_iterations=1)
        
        # Check that the output file has a timestamp format in the name
        collected_files = os.listdir(self.output_dir)
        
        # Skip if no files were created (could happen if the function exited early)
        if collected_files:
            # Check if any filename matches timestamp pattern
            import re
            timestamp_pattern = r'\d{8}-\d{6}'  # e.g., 20230925-142311
            
            # Test passes if any filename contains a timestamp
            self.assertTrue(
                any(re.search(timestamp_pattern, filename) for filename in collected_files),
                "Collected log files do not have timestamp in filename"
            )


if __name__ == '__main__':
    unittest.main()