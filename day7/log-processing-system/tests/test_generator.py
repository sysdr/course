#!/usr/bin/env python3
# test_generator.py - Unit tests for the log generator component

import unittest
import os
import re
import time
import subprocess
import sys

# Assuming generator.py is in the parent directory
sys.path.append('..')
from generator.generator import generate_log, write_logs

class TestGenerator(unittest.TestCase):
    """Test cases for the log generator component"""
    
    def setUp(self):
        """Set up test environment"""
        # Create test output directory if it doesn't exist
        if not os.path.exists('test_output'):
            os.makedirs('test_output')
    
    def tearDown(self):
        """Clean up after tests"""
        # Remove test files
        for file in os.listdir('test_output'):
            os.remove(os.path.join('test_output', file))
    
    def test_generate_log_apache_format(self):
        """Test that generated Apache logs have the correct format"""
        # Generate an Apache format log
        log = generate_log('apache')
        
        # Apache log regex pattern
        apache_pattern = r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3} - - \[\d{2}/[A-Za-z]{3}/\d{4}:\d{2}:\d{2}:\d{2} [+-]\d{4}\] "(GET|POST|PUT|DELETE) /[a-zA-Z0-9/._]+ HTTP/\d\.\d" \d{3} \d+ ".*" ".*"$'
        
        # Verify the log matches the Apache format
        self.assertTrue(re.match(apache_pattern, log), f"Log does not match Apache format: {log}")
    
    def test_generate_log_json_format(self):
        """Test that generated JSON logs have the correct format"""
        # Generate a JSON format log
        log = generate_log('json')
        
        # Verify it's valid JSON with required fields
        import json
        try:
            log_obj = json.loads(log)
            # Check required fields
            required_fields = ['timestamp', 'level', 'message']
            for field in required_fields:
                self.assertIn(field, log_obj, f"Missing required field: {field}")
        except json.JSONDecodeError:
            self.fail(f"Generated log is not valid JSON: {log}")
    
    def test_write_logs_rate(self):
        """Test that logs are written at approximately the specified rate"""
        output_file = os.path.join('test_output', 'rate_test.log')
        rate = 10  # 10 logs per second
        duration = 3  # 3 seconds
        
        # Start writing logs in a separate process
        process = subprocess.Popen(
            [sys.executable, '-c', 
             f"import sys; sys.path.append('..'); from generator.generator import write_logs; write_logs('{output_file}', {rate}, 'apache', count={rate*duration})"],
            stdout=subprocess.PIPE
        )
        
        # Wait for the process to complete
        start_time = time.time()
        process.wait()
        end_time = time.time()
        
        # Check the number of logs written
        with open(output_file, 'r') as f:
            logs = f.readlines()
        
        # Allow for some variance in the timing (±20%)
        expected_logs = rate * duration
        self.assertGreaterEqual(len(logs), expected_logs * 0.8, 
                               f"Too few logs written. Expected ~{expected_logs}, got {len(logs)}")
        self.assertLessEqual(len(logs), expected_logs * 1.2, 
                            f"Too many logs written. Expected ~{expected_logs}, got {len(logs)}")
        
        # Check the duration was approximately correct
        actual_duration = end_time - start_time
        self.assertGreaterEqual(actual_duration, duration * 0.8,
                               f"Duration too short. Expected ~{duration}s, took {actual_duration:.2f}s")
        self.assertLessEqual(actual_duration, duration * 1.5, 
                            f"Duration too long. Expected ~{duration}s, took {actual_duration:.2f}s")
    
    def test_error_handling(self):
        """Test error handling for invalid parameters"""
        # Test with invalid format
        with self.assertRaises(ValueError):
            generate_log('invalid_format')
        
        # Test with invalid rate
        with self.assertRaises(ValueError):
            write_logs('test_output/invalid.log', -5, 'apache')
    
    def test_log_content_variation(self):
        """Test that generated logs have variation"""
        # Generate multiple logs
        logs = [generate_log('apache') for _ in range(10)]
        
        # Check that the logs are not all identical
        unique_logs = set(logs)
        self.assertGreater(len(unique_logs), 1, 
                          "Generated logs show no variation")


if __name__ == '__main__':
    unittest.main()
